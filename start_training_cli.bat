python tools/vqgan/extract_vq.py data     --num-workers 1 --batch-size 16     --config-name  "firefly_gan_vq"     --checkpoint-path "checkpoints/fish-speech-1.5/firefly-gan-vq-fsq-8x1024-21hz-generator.pth"

python tools/llama/build_dataset.py     --input "data"     --output "data/protos"     --text-extension .lab     --num-workers 16

python fish_speech/train.py --config-name text2semantic_finetune     project=$project     +lora@model.model.lora_config=r_8_alpha_16