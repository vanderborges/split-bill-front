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

## Firebase App Distribution (instalar direto no Android e iOS, sem loja)

Projeto Firebase: `split-bill-f135e`
Android `applicationId` / iOS `bundle id`: `com.dividiai.app`

### 1. Instalar e logar no Firebase CLI (uma vez só)

```bash
npm install -g firebase-tools
firebase login
```

### 2. Registrar os apps no projeto Firebase (uma vez só, se ainda não existirem)

```bash
firebase apps:create android --package-name com.dividiai.app --project split-bill-f135e "DividiAi Android"
firebase apps:create ios --bundle-id com.dividiai.app --project split-bill-f135e "DividiAi iOS"
firebase apps:list --project split-bill-f135e
```

Guarde o `App ID` (formato `1:XXXXXXXXXX:android:...` / `...:ios:...`) que aparece no `apps:list` — ele é usado no passo de distribuição.

No Firebase Console (console.firebase.google.com > projeto split-bill-f135e > App Distribution), crie um grupo de testers (ex: "amigos") e adicione os e-mails de quem vai testar.

### 3. Android — build e distribuição

Na pasta `split-bill-front`:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<url-da-api>
```

Gera `build/app/outputs/flutter-apk/app-release.apk`.

```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app <ANDROID_APP_ID> \
  --groups "amigos" \
  --release-notes "Build de teste"
```

Os testers recebem um e-mail com link para instalar o app direto no celular (fora da Play Store).

> Nota: o `release` do Android hoje está assinado com a chave de debug (`signingConfig = signingConfigs.getByName("debug")` em `android/app/build.gradle.kts`). Isso funciona para distribuição via App Distribution, mas antes de publicar na Play Store é preciso configurar uma keystore de release de verdade.

### 4. iOS — build e distribuição

Gerar o `.ipa` exige Xcode, ou seja, um Mac (não dá para compilar iOS no Windows). Opções:

- Usar um Mac (próprio ou de terceiros) com Xcode instalado:
  ```bash
  flutter build ipa --release --dart-define=API_BASE_URL=https://<url-da-api>
  firebase appdistribution:distribute build/ios/ipa/*.ipa \
    --app <IOS_APP_ID> \
    --groups "amigos" \
    --release-notes "Build de teste"
  ```
- Usar um serviço de CI com Mac na nuvem (ex: Codemagic, tem plano free para Flutter) configurado para buildar o `.ipa` e enviar automaticamente para o Firebase App Distribution a cada push.

Além disso, testar/distribuir no iOS via TestFlight/App Distribution exige uma conta Apple Developer Program (paga, ~US$99/ano) para gerar o certificado e o provisioning profile — diferente do Android, que não precisa de conta paga para instalar fora da loja.
