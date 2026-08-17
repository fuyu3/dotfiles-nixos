{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      twemoji-color-font
      noto-fonts-cjk-sans
      noto-fonts
      nerd-fonts.jetbrains-mono
      nerd-fonts.ubuntu-mono
      rubik 
    ];

    fontconfig = {
      defaultFonts = {
        emoji = [ "Twitter Color Emoji" ];
      };
    };
  };
}
