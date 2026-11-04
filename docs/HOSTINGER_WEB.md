# Personal Gym — Deploy Web (Hostinger)

## O que foi gerado

Após o build:

| Caminho | Uso |
|---------|-----|
| `deploy/hostinger_web/` | Pasta pronta para upload |
| `deploy/personal_gym_web_hostinger.zip` | ZIP para extrair no `public_html` |

Inclui `index.html`, `main.dart.js`, assets, CanvasKit e `.htaccess` (SPA).

## Build local

```bash
# 1) Confirme dart_defines.prod.json (SUPABASE_URL + SUPABASE_ANON_KEY)
cp dart_defines.example.json dart_defines.prod.json   # se ainda não existir

# 2) Gere a pasta + ZIP
chmod +x scripts/build_web_hostinger.sh
./scripts/build_web_hostinger.sh
```

Se o site ficar em subpasta (ex.: `https://seudominio.com/app/`):

```bash
./scripts/build_web_hostinger.sh dart_defines.prod.json /app/
```

## Upload no Hostinger

1. Painel Hostinger → **Arquivos** → **Gerenciador de Arquivos**
2. Abra `public_html` (domínio principal) ou a pasta do subdomínio
3. Apague o `index.html` padrão da Hostinger (se existir)
4. Faça upload de `deploy/personal_gym_web_hostinger.zip`
5. Clique com o direito → **Extract**
6. Confirme que na raiz existem: `index.html`, `main.dart.js`, `.htaccess`, pastas `assets/` e `canvaskit/`
7. Abra o domínio no navegador

## Supabase (obrigatório para login)

No [Dashboard Supabase](https://supabase.com/dashboard) → **Authentication → URL Configuration**:

1. **Site URL:** `https://SEU-DOMINIO.com`
2. **Redirect URLs** (adicione):
   - `https://SEU-DOMINIO.com/**`
   - `https://SEU-DOMINIO.com/`
   - `apppersonal://login-callback` (app mobile, se já usava)

Sem isso, magic link / reset de senha podem falhar na web.

## Checklist pós-deploy

- [ ] Site abre (não fica em branco)
- [ ] Login com e-mail/senha funciona
- [ ] Console do navegador (F12) sem erro 404 em `main.dart.js` / `flutter.js`
- [ ] HTTPS ativo (SSL Hostinger)

## Limitações na web

- Live Activities / biometria / notificações locais: só mobile
- Banco local (Drift) usa IndexedDB no browser — dados ficam naquele navegador
- Sync com Supabase funciona como no app (com anon key no build)

## Problemas comuns

| Sintoma | Solução |
|---------|---------|
| Página em branco | Confira `base-href` e se os arquivos estão na raiz correta |
| 404 ao recarregar rota | `.htaccess` não foi enviado (ative “mostrar arquivos ocultos”) |
| Login / Auth falha | Site URL e Redirect URLs no Supabase |
| “Supabase desativado” | Rebuild com `--dart-define-from-file=dart_defines.prod.json` |
| “When compiling to the web, the `web` parameter needs to be set” / banco local | Rebuild com `web/sqlite3.wasm` + `web/drift_worker.js` (já incluídos no script) e reenvie o ZIP |
