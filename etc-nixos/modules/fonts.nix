{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      twemoji-color-font
      noto-fonts-cjk-sans
      noto-fonts-extra
      nerd-fonts.jetbrains-mono
      nerd-fonts.ubuntu-mono
    ];

    fontconfig = {
      defaultFonts = {
        emoji = [ "Twitter Color Emoji" ];
      };
    };
  };
}