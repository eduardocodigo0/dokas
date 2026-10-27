# Doka's Lanches — cardápio digital

SPA (Single Page Application) para o **Doka's Lanches**, construída com
[Gleam](https://gleam.run) e [Lustre](https://lustre.build) (arquitetura
Model-Update-View). Os clientes montam o pedido a partir do cardápio digital e
enviam uma mensagem formatada diretamente pelo WhatsApp.

## Funcionalidades

- Cardápio completo dividido em abas: Lanches, Refrigerantes, Bebidas em Lata e Sucos.
- Variações de tamanho/preço (ex.: Lata, 600 ml, 1 L, 2 L).
- Carrinho com controles de quantidade, remoção de itens, subtotal e total.
- Limites de segurança: no máximo **20 unidades por item** e **50 itens no carrinho**.
- Mensagens de erro visuais quando os limites são atingidos.
- Checkout desabilitado + aviso enquanto faltar o carrinho ou campos obrigatórios.
- Tipo de pedido obrigatório: **retirada no estabelecimento** ou **entrega** (com endereço obrigatório).
- Forma de pagamento obrigatória: **Pix**, **cartão de débito**, **cartão de crédito** ou **dinheiro** (nota para troco quando em dinheiro).
- Campos de nome e observações sanitizados (remoção de caracteres de controle e
  limite de tamanho); todo texto é renderizado como texto puro (sem HTML/XSS).
- Persistência do carrinho no `localStorage` (o pedido sobrevive a um recarregamento).
- Integração com o WhatsApp via `https://wa.me/...`, com o texto codificado
  (`uri.percent_encode`, equivalente ao `encodeURIComponent`).
- Layout responsivo com Tailwind CSS v4 e paleta laranja.

## Tecnologias

- [Gleam](https://gleam.run) 1.x
- [Lustre](https://lustre.build) 5.x
- [Tailwind CSS](https://tailwindcss.com) v4
- `lustre_dev_tools` (servidor de desenvolvimento e build)

## Estrutura

```text
src/
  dokas.gleam         # entrypoint (monta a aplicação em #app)
  dokas.css           # entrada do Tailwind v4
  dokas/
    app.gleam         # Model, Msg, init, update e view
    domain.gleam      # cardápio, regras de carrinho, sanitização e URL do WhatsApp
    ffi.gleam         # bindings de localStorage (JS + stub Erlang)
    ffi_ffi.mjs       # implementação JavaScript
  dokas_ffi.erl       # stub Erlang (permite `gleam test`)
test/
  dokas_test.gleam    # testes da lógica pura
```

## Como rodar

Pré-requisitos: Gleam 1.19+ e Erlang/OTP (para o `lustre_dev_tools`). O Bun e o
Tailwind CLI são baixados automaticamente na primeira execução.

```sh
gleam deps download             # baixa as dependências
gleam run -m lustre/dev start   # servidor de desenvolvimento (http://localhost:1234)
```

## Build de produção

```sh
gleam run -m lustre/dev build --minify
```

Os artefatos (JavaScript + CSS + `index.html`) são gerados em `dist/`.

## Deploy (GitHub Pages)

O deploy é **manual**, pela pipeline `.github/workflows/deploy.yml`:

1. No GitHub, acesse **Actions → Deploy to GitHub Pages → Run workflow** (branch `main`), ou rode:
   ```sh
   gh workflow run deploy.yml
   ```
2. A pipeline compila o app (`gleam run -m lustre/dev build --minify`), ajusta os caminhos dos assets para o subdiretório do Pages e publica o conteúdo de `dist/`.

Site publicado: <https://eduardocodigo0.github.io/dokas/>

O gatilho é apenas `workflow_dispatch`. Para deploy automático a cada push, adicione ao workflow:

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
```

## Testes

```sh
gleam test                     # alvo Erlang
gleam test --target javascript # alvo JavaScript (requer Node.js)
gleam format --check src test  # verificação de formatação
```

## Configuração do WhatsApp

O número que recebe os pedidos fica em `src/dokas/domain.gleam`:

```gleam
pub const whatsapp_number = "5518997327064"
```

Use sempre o formato internacional (código do país + DDD + número), sem `+`,
espaços ou símbolos.

## Regras de negócio

- `max_per_item = 20` e `max_total = 50` (em `src/dokas/domain.gleam`).
- Preços são armazenados em **centavos** (`Int`) para evitar erros de ponto flutuante.
- O checkout exige tipo de pedido, endereço (se entrega), forma de pagamento e nota de troco (se dinheiro).
- A mensagem do WhatsApp usa apenas texto (sem emojis) para evitar caracteres corrompidos (`��`).

