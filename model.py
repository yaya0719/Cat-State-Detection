import torch
import torch.nn as nn
from model_util import (TubeletEmbedding, Attention, TransformerEncoder, TokenProcessor)

#MODEL 2
class ViViT_Factorized(nn.Module):
    def __init__(self, in_channels, embed_dim, patch_size, tubelet_size, num_heads, mlp_dim,
                 num_layers_spatial, num_layers_temporal, num_classes, num_frames, img_size, droplayer_p):
        super().__init__()

        # **Tubelet Embedding**
        self.tubelet_embedding = TubeletEmbedding(in_channels, embed_dim, patch_size, tubelet_size)

        # **計算影片的 Token 數量**
        num_patches = (img_size // patch_size) * (img_size // patch_size)
        effective_num_frames = num_frames // tubelet_size  # 下採樣後的幀數
        self.num_tokens = effective_num_frames * num_patches  # 正確的 token 數量

        # **CLS Token & 位置編碼**
        self.cls_token = nn.Parameter(torch.randn(1, 1, embed_dim))
        self.pos_embedding = nn.Parameter(torch.randn(1, self.num_tokens + 1, embed_dim))

        # **空間 Transformer（Spatial Transformer Encoder）**
        self.spatial_transformer = TransformerEncoder(embed_dim, num_heads, mlp_dim, num_layers_spatial, droplayer_p)

        # **時間 Transformer（Temporal Transformer Encoder），層數/2用來減緩過擬和**
        self.temporal_transformer = TransformerEncoder(embed_dim, num_heads, mlp_dim, num_layers_temporal//2, droplayer_p)

        # **LayerNorm + MLP Head（分類）**
        self.norm = nn.LayerNorm(embed_dim)
        self.mlp_head = nn.Linear(embed_dim, num_classes)

    def forward(self, x):
        B, C, T, H, W = x.shape  # B: 批次大小, C:通道數, T:幀數, H:高, W:寬

        # Step 1: 影片 Token 化
        x = self.tubelet_embedding(x)  # (B, N, embed_dim)

        # Step 2: 加入 CLS Token & 位置編碼
        x = TokenProcessor.add_cls_token(x, self.cls_token)  # (B, N+1, embed_dim)
        x = TokenProcessor.add_positional_embedding(x, self.pos_embedding)  # (B, N+1, embed_dim)

        # Step 3: **空間 Transformer**
        x = self.spatial_transformer(x)  # (B, N+1, embed_dim)

        # Step 4: **時間壓縮**
        temporal_method = "gap"
        patch_tokens = TokenProcessor.temporal_embedding(x, method=temporal_method)  # (B, 1, embed_dim)
        x = torch.cat((x[:, 0:1], patch_tokens), dim=1)  # (B, T+1, embed_dim)

        # Step 5: **時間 Transformer**
        x = self.temporal_transformer(x)  # (B, T+1, embed_dim)

        # Step 6: **分類**
        x = self.norm(x[:, 0])  # (B, embed_dim)
        x = self.mlp_head(x)  # (B, num_classes)

        return x
