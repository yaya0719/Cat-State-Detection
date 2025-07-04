import torch
import torch.nn as nn

class TubeletEmbedding(nn.Module):
    # RGB、小立方體經過特徵提取後的壓縮表示、立方體長寬、立方體的時間
    def __init__(self, in_channels, embed_dim, patch_size, tubelet_size, kernel_init_method=None):
        super().__init__()

        # 3D 卷積，將影片切割成小塊，出來的結果是長、寬、時間的塊數
        self.conv3d = nn.Conv3d(
            in_channels, embed_dim,
            kernel_size=(tubelet_size, patch_size, patch_size),
            stride=(tubelet_size, patch_size, patch_size),
            bias=True
        )

        # 選擇初始化函數
        if kernel_init_method == 'central_frame_initializer':
            self.kernel_initializer = central_frame_initializer()
        elif kernel_init_method == 'average_frame_initializer':
            self.kernel_initializer = average_frame_initializer()
        else:
            self.kernel_initializer = None

        # 初始化權重
        if self.kernel_initializer is not None:
            with torch.no_grad():
                self.conv3d.weight.data = self.kernel_initializer(self.conv3d.weight)

    def forward(self, x):
        # Input shape: (B, C, T, H, W)
        x = self.conv3d(x)  # (B, embed_dim, num_tubelets, num_patches_h, num_patches_w)

        # 取得新形狀
        B, embed_dim, num_tubelets, num_patches_h, num_patches_w = x.shape

        # 重新排列維度以適應 Transformer (B, num_tubelets, num_patches_h, num_patches_w, embed_dim)
        x = x.permute(0, 2, 3, 4, 1).contiguous()

        # 展平成 (B, N, embed_dim)，其中 N = num_tubelets * num_patches_h * num_patches_w
        num_tokens = num_tubelets * num_patches_h * num_patches_w
        x = x.view(B, num_tokens, embed_dim)

        return x

def central_frame_initializer():
    def init(weight):
        weight.zero_()
        center_time_idx = weight.shape[2] // 2
        weight[:, :, center_time_idx, :, :] = torch.randn_like(weight[:, :, center_time_idx, :, :]) * 0.5
        return weight
    return init

def average_frame_initializer():
    def init(weight):
        avg_weight = weight.mean(dim=2, keepdim=True)
        weight.copy_(avg_weight.expand_as(weight) + torch.randn_like(weight) * 0.01)
        return weight
    return init

#處理時間、空間、class的token embeding
class TokenProcessor:
    """
    封裝 CLS Token、Positional Encoding、Temporal Encoding 的工具類別
    """

    @staticmethod
    def add_cls_token(x, cls_token):
        """加入 CLS Token"""
        B, N, C = x.shape
        cls_token_expanded = cls_token.expand(B, -1, -1)
        return torch.cat((cls_token_expanded, x), dim=1)  # (B, N+1, embed_dim)

    @staticmethod
    def add_positional_embedding(x, pos_embedding):
        """加入 Positional Embedding"""
        return x + pos_embedding[:, :x.shape[1], :]

    @staticmethod
    def temporal_embedding(x, method="cls"):
        """
        method 1
            a video-> n frames, n frames have n cls token，
            so we use n cls token as temperal information

        method 2
            論文 : a global average pooling from the tokens output by the spatial encoder
            a video-> n frames, 每個frame有P個patch，將這p個patch排除cls token後取平均變成1個token，稱作avg_token
            n frames就會有n個avg_token，就可以當成temperal information
        """

        if method == "cls":
            # **使用 CLS Token 作為 Temporal Information**
            return x[:, 0:1]  # 取出 CLS Token (B, 1, embed_dim)

        elif method == "gap":
            # **使用 GAP 壓縮所有 Patch Token，得到該幀的全局資訊**
            return x[:, 1:].mean(dim=1, keepdim=True)  # (B, 1, embed_dim)

        else:
            raise ValueError("`method` 必須是 'cls' 或 'gap'")

#注意力機制
class Attention(nn.Module):
    def __init__(self, embed_dim, num_heads, dropout=0.1):
        super().__init__()
        self.num_heads = num_heads
        self.head_dim = embed_dim // num_heads
        assert embed_dim % num_heads == 0, "Embedding dimension must be divisible by number of heads."

        # QKV 變換
        self.query = nn.Linear(embed_dim, embed_dim)
        self.key = nn.Linear(embed_dim, embed_dim)
        self.value = nn.Linear(embed_dim, embed_dim)

        # 最終輸出層
        self.out = nn.Linear(embed_dim, embed_dim)
        self.dropout = nn.Dropout(dropout)

    def forward(self, x):
        B, N, C = x.shape

        # Q, K, V 計算並 reshape
        Q = self.query(x).view(B, N, self.num_heads, self.head_dim).transpose(1, 2)
        K = self.key(x).view(B, N, self.num_heads, self.head_dim).transpose(1, 2)
        V = self.value(x).view(B, N, self.num_heads, self.head_dim).transpose(1, 2)

        # Scaled Dot-Product Attention
        attn = (Q @ K.transpose(-2, -1)) / (self.head_dim ** 0.5)
        attn = attn.softmax(dim=-1)
        attn = self.dropout(attn)  # 避免過擬合

        # 加權和
        out = (attn @ V).transpose(1, 2).contiguous().view(B, N, C)

        # Dropout 和輸出層
        return self.out(self.dropout(out))

# model1和model2的TransformerEncoderBlock
class TransformerEncoderBlock(nn.Module):
    def __init__(self, embed_dim, num_heads, mlp_dim, dropout=0.1):
        super().__init__()

        # 多頭自注意力層
        self.attn = Attention(embed_dim, num_heads, dropout)
        # 用於注意力層前的 LayerNorm
        self.norm_attn = nn.LayerNorm(embed_dim)

        # mlp 區塊
        self.mlp = nn.Sequential(
            nn.Linear(embed_dim, mlp_dim),
            nn.GELU(),
            nn.Linear(mlp_dim, embed_dim),
            nn.Dropout(dropout)
        )
        # 用於 mlp 區塊前的 LayerNorm
        self.norm_mlp = nn.LayerNorm(embed_dim)

        # 通用 dropout
        self.dropout = nn.Dropout(dropout)

    def forward(self, x):
        # Attention 子層: 先正規化，再計算注意力，加入 dropout，最後與原輸入做殘差連接
        residual = x
        x = self.norm_attn(x)
        x = self.attn(x)
        x = self.dropout(x)
        x = residual + x

        # MLP 子層: 同樣先正規化，再計算 MLP，加入 dropout，最後與之前的輸入做殘差連接
        residual = x
        x = self.norm_mlp(x)
        x = self.mlp(x)
        x = self.dropout(x)
        x = residual + x

        return x


# transformer layer : 將多個 TransformerEncoderBlock 堆疊起來
class TransformerEncoder(nn.Module):
    def __init__(self, embed_dim, num_heads, mlp_dim, num_layers, dropout=0.1):
        super().__init__()
        self.layers = nn.ModuleList()  # 創建一個空的 ModuleList

        # 使用 for 迴圈來添加 num_layers 個 TransformerEncoderBlock
        for _ in range(num_layers):
            self.layers.append(TransformerEncoderBlock(embed_dim, num_heads, mlp_dim, dropout))

    def forward(self, x):
        #layer : 當前的所在的block， layers : 全部的block
        for layer in self.layers:
            x = layer(x)
        return x
