{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
      noto-fonts
      nerd-fonts.jetbrains-mono
      nerd-fonts.ubuntu-mono
      rubik 
    ];

    fontconfig = {
      defaultFonts = {
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
