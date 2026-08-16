# Repositório unificado

Antes disso, o repositório estava dividido em `etc-nixos/` (pra
`/etc/nixos`) e `home-fuyu-dotfiles/` (pra `/home/fuyu/dotfiles`), com
`home.nix` referenciado de `/etc/nixos` via flake input `git+file://`
apontando pra fora da árvore. Isso causou toda a dor de cabeça de
`NAR hash mismatch`, `path:` vs `git+file://`, e o descompasso de
filesystem entre o live ISO e o disco de destino durante a instalação.

Agora é **um repositório só**, pensado pra viver inteiro dentro de
`/home/fuyu` (ex: `/home/fuyu/dotfiles`). `home.nix` é importado por
caminho relativo (`import ./home.nix`) direto no `flake.nix` — sem input
de flake separado pra ele, sem `git+file://`, sem depender de nenhum
caminho absoluto pra fora da própria árvore do repo. Isso elimina de vez
aquela categoria inteira de erro.

## O que mudou estruturalmente

- `etc-nixos/configuration.nix` → `configuration.nix` (raiz)
- `etc-nixos/flake.nix` → `flake.nix` (raiz), sem o input `dotfiles`
- `etc-nixos/modules/` → `modules/` (raiz) — **intocado**, inclusive suas
  adições (`audio.nix`, `connections.nix`, `fonts.nix`, Ollama+CUDA no
  `nvidia.nix`, os pacotes novos em `packages.nix`)
- `home-fuyu-dotfiles/home.nix` → `home.nix` (raiz)
- `home-fuyu-dotfiles/config/` → `config/` (raiz) — todos os dotfiles,
  intocados
- Usei `git mv` em cada arquivo, então o histórico de commits de cada um
  continua rastreável (`git log --follow <arquivo>` funciona normal)

## O único arquivo que falta: `hardware-configuration.nix`

Ele não veio no zip que você me passou — normal, é específico da sua
máquina (UUIDs de disco) e provavelmente nunca foi commitado. O
`configuration.nix` já importa `./hardware-configuration.nix` sem
comentário, então **sem esse arquivo na raiz o `nixos-rebuild` vai falhar**
na avaliação. Antes do primeiro rebuild com esse repositório novo:

```bash
cp /etc/nixos/hardware-configuration.nix ~/dotfiles/hardware-configuration.nix
```

(ajuste `~/dotfiles` pro caminho real onde você colocar essa pasta)

## Como aplicar

```bash
# coloca a pasta inteira em /home/fuyu (substitua "dotfiles" pelo nome
# que preferir dar pra pasta)
cd /home/fuyu
# ... extraia este zip aqui, ou copie o conteúdo pra dentro de ~/dotfiles ...

cp /etc/nixos/hardware-configuration.nix /home/fuyu/dotfiles/hardware-configuration.nix

sudo nixos-rebuild switch --flake /home/fuyu/dotfiles#default
```

Repare que **não precisa mais copiar nada pra `/etc/nixos`** — o flake
inteiro roda direto da pasta dentro do seu usuário. `/etc/nixos` pode
inclusive ficar só com o `hardware-configuration.nix` original gerado pelo
instalador (o Nix não liga pra isso, só usamos o caminho que você passar
em `--flake`).

Se quiser rodar de dentro da própria pasta sem digitar o caminho inteiro:

```bash
cd /home/fuyu/dotfiles
sudo nixos-rebuild switch --flake .#default
```

`nixos-rebuild switch` **sem** `--flake` só funciona automaticamente se
existir um `flake.nix` em `/etc/nixos` especificamente — como o nosso
agora mora em `/home/fuyu/dotfiles`, sempre vai precisar do `--flake` (ou
de um alias, como já tínhamos combinado antes).

## Nada mais foi alterado

Módulos, pacotes, dotfiles, tudo continua exatamente como você deixou —
essa reorganização só mexeu em *onde* os arquivos ficam e em *como*
`home.nix` é referenciado, não no conteúdo de nenhum módulo.
