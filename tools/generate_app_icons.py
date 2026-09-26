import os
from PIL import Image, ImageDraw

def generate_icons():
    source_path = "assets/images/vocivo_app_icon.png"
    if not os.path.exists(source_path):
        raise FileNotFoundError(f"Source icon not found at {source_path}")

    img = Image.open(source_path).convert("RGBA")
    print(f"Loaded master icon: {img.size}")

    # 1. Windows ICO
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    windows_ico_path = "windows/runner/resources/app_icon.ico"
    os.makedirs(os.path.dirname(windows_ico_path), exist_ok=True)
    
    # Generate list of resized images for ICO
    ico_images = [img.resize(s, Image.Resampling.LANCZOS) for s in ico_sizes]
    # Pillow saves ICO with all provided sizes
    ico_images[0].save(
        windows_ico_path,
        format="ICO",
        sizes=ico_sizes,
        append_images=ico_images[1:]
    )
    print(f"Generated Windows ICO at: {windows_ico_path} with sizes: {ico_sizes}")

    # 2. Android Mipmap Icons
    android_sizes = {
        "mipmap-mdpi": (48, 48),
        "mipmap-hdpi": (72, 72),
        "mipmap-xhdpi": (96, 96),
        "mipmap-xxhdpi": (144, 144),
        "mipmap-xxxhdpi": (192, 192),
    }

    def make_round(im, size):
        im_resized = im.resize(size, Image.Resampling.LANCZOS)
        mask = Image.new('L', size, 0)
        draw = ImageDraw.Draw(mask)
        draw.ellipse((0, 0, size[0], size[1]), fill=255)
        round_im = Image.new('RGBA', size, (0, 0, 0, 0))
        round_im.paste(im_resized, (0, 0), mask=mask)
        return round_im

    for folder, size in android_sizes.items():
        res_dir = os.path.join("android/app/src/main/res", folder)
        os.makedirs(res_dir, exist_ok=True)
        
        # Standard icon
        standard_icon = img.resize(size, Image.Resampling.LANCZOS)
        standard_path = os.path.join(res_dir, "ic_launcher.png")
        standard_icon.save(standard_path, format="PNG")
        
        # Round icon
        round_icon = make_round(img, size)
        round_path = os.path.join(res_dir, "ic_launcher_round.png")
        round_icon.save(round_path, format="PNG")
        print(f"Generated Android {folder} ({size[0]}x{size[1]}): ic_launcher.png & ic_launcher_round.png")

    # 3. Web icons
    web_dir = "web"
    if os.path.exists(web_dir):
        favicon = img.resize((32, 32), Image.Resampling.LANCZOS)
        favicon.save(os.path.join(web_dir, "favicon.png"), format="PNG")
        
        web_icons_dir = os.path.join(web_dir, "icons")
        os.makedirs(web_icons_dir, exist_ok=True)
        
        img.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-192.png"), format="PNG")
        img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-512.png"), format="PNG")
        img.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), format="PNG")
        img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), format="PNG")
        print("Generated Web icons (favicon, 192, 512, maskable).")

    print("All app icons successfully generated!")

if __name__ == "__main__":
    generate_icons()
