import os
from PIL import Image

root = os.path.dirname(os.path.abspath(__file__))


def main():
    red_img = Image.new("RGB", (2, 2), (250, 0, 0))
    red_img.save(root + "/r_img.png", "PNG")
    red_img.save(root + "/r_img.jpg", "JPEG")

    green_img = Image.new("RGB", (2, 2), (0, 250, 0))
    green_img.save(root + "/g_img.png")
    green_img.save(root + "/g_img.jpg", "JPEG")

    blue_img = Image.new("RGB", (2, 2), (0, 0, 250))
    blue_img.save(root + "/b_img.png")
    blue_img.save(root + "/b_img.jpg", "JPEG")


if __name__ == "__main__":
    main()
