# Deploy

## Render Static Site

Configure a variavel de ambiente:

```text
API_BASE_URL=https://<url-da-api>
```

Build command:

```bash
bash render-build.sh
```

Publish directory:

```text
build/web
```

## Firebase Hosting

Build:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://<url-da-api>
```

Deploy:

```bash
firebase deploy
```
