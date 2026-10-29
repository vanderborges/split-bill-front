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

### Problemas conhecidos no iOS (Codemagic)

**403 "PLA Update available" ao buscar os arquivos de assinatura**

```text
GET https://api.appstoreconnect.apple.com/v1/bundleIds?... returned 403: Unable to process request - PLA Update available - You currently don't have access to this membership resource. To resolve this issue, your team's Account Holder, ..., must agree to the latest Program License Agreement.
Failed to fetch iOS signing files using App Store Connect API
```

A Apple publicou uma nova versão do Program License Agreement e bloqueia a API do App Store Connect até o Account Holder aceitar. Não é problema de código nem de configuração do Codemagic.

1. Entrar em https://developer.apple.com/account com o Apple ID do Account Holder e aceitar o contrato no banner "Review Agreement" (se o banner não aparecer, sair e entrar de novo, usar janela anônima ou abrir "Membership details").
2. Conferir em https://appstoreconnect.apple.com → Business se há outro contrato pendente e aceitar.
3. Esperar alguns minutos (pode levar até ~1 hora para propagar) e rodar o build iOS de novo.

Só o Account Holder consegue aceitar (usuário Admin não tem a opção). Não é preciso trocar a API key do App Store Connect nem os certificados.
