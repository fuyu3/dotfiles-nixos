# Caelestia.Blobs — extraído e testado

Fonte: `plugin/src/Caelestia/Blobs/` dentro do `shell-main.zip` que você
mandou (caelestia-dots/shell, GPL-3.0 — a `LICENSE` original está nesta
pasta). **Compilei esse extrato aqui e ele builda e linka completo** — não
é suposição, testei de verdade.

## O que é, de fato

Isso NÃO é o m3shapes. É outro plugin C++, com `QSGMaterial` customizado —
o sistema real de "fusão" que conecta barra, dashboard, sidebar e popouts
no caelestia-shell.

- `BlobGroup` — agrupa várias formas que devem se fundir entre si.
- `BlobRect` — um retângulo arredondado (com raio por canto) que pertence a
  um grupo. Tem física de mola própria (`stiffness`, `damping`,
  `deformScale`): quando o item se move rápido, ele "espreme" de verdade
  (uma matriz de deformação 2x2 anima via spring), não é só uma escala.
- `BlobInvertedRect` — um "quadro" com um buraco no meio (a moldura da tela
  inteira, por exemplo), que também participa da fusão — é o que faz um
  painel "afundar" na borda quando encosta nela.
- `exclude` / `excludeCorners` — listas de outros `BlobRect`s com quem ESSE
  retângulo não deve se fundir (dois popouts vizinhos que não devem virar
  um blob só, por exemplo).

O shader (`src/shaders/blob.frag`) calcula, por pixel, o SDF de até 16
retângulos por vez (de um array de até 80), faz `min` de todos e depois
`smin` (smooth min circular, não polinomial) só nos pares que não estão na
lista de exclusão e que estão realmente perto um do outro — é isso que dá
o "pescoço" gooey exatamente onde duas formas se aproximam, sem afetar
formas distantes.

## Por que isso é MELHOR que os shaders que te dei antes

O que fiz manualmente (`bar-menu-neck.frag`) é uma versão de brinquedo
disso: só 2 caixas fixas, sem física, sem grupo, sem exclusão seletiva.
Funciona pro exemplo simples, mas não escala — se você quiser 5 elementos
da barra todos se fundindo entre si condicionalmente (como o caelestia
faz), reimplementar isso à mão vira uma bagunça rápido. Usar o
`Caelestia.Blobs` de verdade resolve isso de fábrica.

## Build

```bash
mkdir build && cd build
cmake .. -G Ninja
ninja
```

Gera o módulo QML em `build/qml/Caelestia/Blobs/` (plugin `.so` + `qmldir`
+ `.qmltypes`). Aponte `QML2_IMPORT_PATH` pra essa pasta (ou pra
`build/qml`, que é a raiz), do mesmo jeito que já faz com o m3shapes — dá
pra ter os dois módulos ao mesmo tempo no import path, sem conflito, URIs
diferentes (`Caelestia.Blobs` vs `M3Shapes`).

No NixOS, o pacote fica igual ao `flake-snippet.md` do m3shapes: um
`stdenv.mkDerivation` com `cmake`/`ninja`/`qt6.qtbase`/`qt6.qtdeclarative`/
`qt6.qtshadertools`, e o mesmo truque de apontar `QML2_IMPORT_PATH` pro
`lib/qt-6/qml` dele. Se quiser, monto esse `default.nix` também.

## Uso básico

```qml
import QtQuick
import Caelestia.Blobs

Item {
    BlobGroup {
        id: group
        color: "#2e2e40"
        smoothing: 24        // raio do "pescoço" — equivalente ao meu neckK
    }

    BlobRect {
        id: button
        group: group
        x: 10; y: 8
        implicitWidth: 90; implicitHeight: 30
        topLeftRadius: 15; topRightRadius: 15
        bottomLeftRadius: 15; bottomRightRadius: 15
    }

    BlobRect {
        id: menu
        group: group
        x: 10; y: button.y + button.implicitHeight
        implicitWidth: 0; implicitHeight: 0   // fechado: sem forma
        topLeftRadius: 16; topRightRadius: 16
        bottomLeftRadius: 16; bottomRightRadius: 16

        states: State {
            name: "open"
            when: menuOpen
            PropertyChanges { menu.implicitWidth: 180; menu.implicitHeight: 150 }
        }
        transitions: Transition {
            NumberAnimation { properties: "implicitWidth,implicitHeight"; duration: 300; easing.type: Easing.OutCubic }
        }
    }
}
```

Repare que aqui você não escreve NENHUM shader — o `BlobGroup` desenha
tudo sozinho. É bem mais próximo do que o caelestia realmente faz do que
o `bar-menu-neck.qml` que te passei antes.

## O que eu NÃO testei

Compilei e confirmei que o `.so`/`qmldir`/`.qmltypes` saem certos — não
testei rodando dentro do quickshell de verdade (não tenho um compositor
Wayland aqui pra isso), então o comportamento visual exato (física de
mola, `exclude`, etc.) eu só posso descrever a partir do shader/header,
não confirmar visualmente. Se algo não bater com o que você vir na tela,
me manda o que apareceu que a gente ajusta.
