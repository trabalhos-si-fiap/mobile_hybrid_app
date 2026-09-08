# Edu Admin — arquivado

Este repositório foi consolidado no
[`trabalhos-si-fiap/edu`](https://github.com/trabalhos-si-fiap/edu) em
setembro de 2026. Ele fica aqui como registro; nada é desenvolvido a partir
dele.

## Onde cada aplicação foi parar

| Pasta | Destino |
|---|---|
| `web-angular/` | `edu/web-admin/`, trazido por `git subtree` com o histórico preservado |
| `mobile-flutter/` | Descontinuado. Cada tela tem equivalente em `edu/front-end-flutter/lib/features/` — a tabela de equivalência está em `edu/web-admin/README-STATUS.md` |
| `api/` (Spring Boot) | Eliminado. Transportadora ainda não tem equivalente; estoque e ocorrência já têm implementação própria em `edu/back-end/commerce-service/`, não herdada deste código — a spec B fecha essa lacuna usando este código como referência |

## Por que

A plataforma passou a rodar sobre um backend só — os microsserviços Python do
`edu`. Manter uma segunda API e um fork do app Flutter significava implementar
cada mudança duas vezes.
