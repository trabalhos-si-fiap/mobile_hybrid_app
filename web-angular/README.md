# Edu Admin — painel web

Painel administrativo e console de atendimento, em Angular 22. O Node roda só
em container; veja a seção "Painel web" do [README da raiz](../README.md).

```bash
# em api/
docker compose up -d                     # painel em http://localhost:4200, junto com a API
docker compose logs -f web               # edições e git pull recompilam sozinhos
docker compose run --rm node test        # testes unitários (Vitest)
docker compose run --rm node run build   # build de produção

# na raiz do repositório
web-angular/e2e/run.sh                   # ponta a ponta (Playwright), numa stack efêmera
```

O proxy do `ng serve` (`proxy.conf.mjs`) manda `/api` para `API_URL`, que no
Compose é `http://api:8080`.
