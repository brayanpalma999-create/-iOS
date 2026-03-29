# iOS Build En GitHub (AtoB)

Este flujo compila `.ipa` para iPhone con firma real desde GitHub Actions.

## 1) Sube el proyecto a GitHub

Si tu carpeta aun no es repo:

```bash
cd "C:\Users\braya\OneDrive\Escritorio\flutter projects\atob_app"
git init
git add .
git commit -m "setup iOS github actions"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/TU_REPO.git
git push -u origin main
```

## 2) Secrets requeridos en GitHub

En `Repo -> Settings -> Secrets and variables -> Actions` crea:

- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_TEAM_ID`
- `IOS_BUNDLE_IDENTIFIER` (opcional, si no lo pones usa el del profile)
- `IOS_KEYCHAIN_PASSWORD` (opcional)

Para modo TestFlight agrega tambien:

- `APPSTORE_API_KEY_ID`
- `APPSTORE_API_ISSUER_ID`
- `APPSTORE_API_PRIVATE_KEY_BASE64`

## 3) Como generar los secretos base64

### Certificado `.p12`

```bash
# macOS
base64 -i ios_distribution.p12 | pbcopy
```

Pega el resultado en `IOS_CERTIFICATE_P12_BASE64`.

```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ruta\ios_distribution.p12"))
```

### Provisioning profile `.mobileprovision`

```bash
# macOS
base64 -i AdHoc.mobileprovision | pbcopy
```

Pega el resultado en `IOS_PROVISIONING_PROFILE_BASE64`.

```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ruta\AdHoc.mobileprovision"))
```

## 4) Ejecutar workflow

En `Actions -> iOS Build And Distribute -> Run workflow`:

- `distribution = ad-hoc` para instalar directo en iPhone (con UDID registrado).
- `distribution = testflight` para subir a TestFlight.

## 5) Instalar en iPhone

### Opcion A: ad-hoc

1. Descarga el artifact `.ipa` del job.
2. Instala con Apple Configurator 2 o Transporter en Mac.
3. El iPhone debe estar incluido en el provisioning profile.

### Opcion B: TestFlight

1. Corre workflow con `distribution = testflight`.
2. Abre App Store Connect -> TestFlight.
3. Cuando termine el processing, instala desde app TestFlight en iPhone.

## Notas

- iOS solo se compila en runners macOS.
- El proyecto esta configurado para iOS 15+.
- Si falla firma, normalmente es mismatch entre `Bundle ID`, `Team ID` y profile.
