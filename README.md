# Veracode Integration Hub

MVP de uma Composite Action que centraliza integrações do Veracode: SCA (Dependency Scanning), Upload & Scan (plataforma), Pipeline Scan e IaC/Container/Secrets. A ação padroniza builds e empacotamento, valida entradas antes de executar e publica apenas logs no console (sem arquivos de relatório), facilitando a adoção do Veracode em múltiplos tipos de projeto.

O que ajuda a mitigar
- Falhas por falta de credenciais obrigatórias (mensagens claras e fail-fast).
- Erros de empacotamento (gera pacotes consistentes por linguagem, com binários e símbolos).
- Inconsistência entre build/artefato e o que o Veracode espera.
- Excesso de configuração: um único `uses:` com toggles e parâmetros por linguagem.

Principais recursos
- Um hub único para SCA, Upload & Scan, Pipeline Scan e IaC.
- Validação de inputs e secrets logo no início, com instruções de correção.
- Instalação automática da Veracode CLI quando necessário (Auto Packager e IaC) em Linux/macOS.
- Builds opcionais por linguagem com empacotamento padronizado (gera um .zip por linguagem).
- Integração com actions oficiais do Veracode (SCA, Pipeline, Upload & Scan).
- upload_guid real capturado após o Upload & Scan via Java API Wrapper (getbuildlist).
- Logs claros com emojis, sem salvar relatórios/artefatos extras.

## Inputs por Domínio

Toggles principais
- enableSCA: Executa SCA (default: "false")
- enableUS: Executa Upload & Scan (default: "false")
- enablePS: Executa Pipeline Scan (default: "false")
- enableIAC: Executa IaC/Container/Secrets (default: "false")
- enableAP: Executa Auto Packager (default: "false")

Credenciais e contexto Veracode
- veracodeApiId: VID
- veracodeApiKey: VKEY
- scaToken: SRCCLR_API_TOKEN para SCA
- iacToken: opcional (IaC usa VID/VKEY por padrão)

Configuração geral
- workingDirectory: diretório base (default: ".")
- debug: modo detalhado de log (default: "false")

Artefatos
- artifact: usa artefato manual (default: "false")
- artifactName: caminho do artefato (obrigatório se artifact=true)

Java (runtime geral)
- javaVersion: ex.: 17 (default: 17)
- javaDistribution: ex.: temurin (default: temurin)

Maven
- maven: ativa build Maven (toggle)
- mavenCmd: comando Maven (override)
- mavenWrapperPath: caminho do wrapper (default: ./mvnw)
- mavenGoals: goals quando não usa mavenCmd (default: -B -DskipTests package)
- mavenProjectDir: subdiretório do projeto (default: .)
- mavenOptions: opções extras (default: --no-transfer-progress)
- mavenOutputDir: saída do pacote (default: dist/veracode-maven)

Gradle
- gradle: ativa build Gradle (toggle)
- gradleCmd: comando Gradle (override)
- gradleWrapperPath: caminho do wrapper (default: ./gradlew)
- gradleTasks: tasks quando não usa gradleCmd (default: assemble -x test)
- gradleProjectDir: subdiretório do projeto (default: .)
- gradleOptions: opções extras (default: --no-daemon)
- gradleIncludeDists: inclui build/distributions/*.zip (default: true)
- gradleOutputDir: saída do pacote (default: dist/veracode-gradle)

Kotlin (via Gradle)
- kotlin: ativa build Kotlin (toggle)
- kotlinCmd: comando (override)
- kotlinWrapperPath, kotlinTasks, kotlinProjectDir, kotlinOptions, kotlinIncludeDists, kotlinOutputDir (semântica igual ao Gradle)

.NET
- dotnet: ativa build .NET (toggle)
- dotnetProject: caminho do .csproj prioritário
- dotnetSolution: caminho do .sln (se não houver project)
- dotnetBuildCmd: override total do build
- dotnetConfiguration: Release/Debug (default: Release)
- dotnetRuntime: RID (ex.: linux-x64, win-x64)
- dotnetSelfContained: true/false (default: false)
- dotnetPublishSingleFile: true/false (default: false)
- dotnetIncludeSymbols: inclui .pdb no pacote (default: true)
- dotnetOutputDir: saída do pacote (default: dist/veracode-dotnet)
- dotnetAdditionalArgs: args extras para `dotnet publish`
- dotnetRestore: executa restore (default: false)
- dotnetRestoreCmd: comando restore (default: dotnet restore)
- nugetConfigPath: caminho para NuGet.config
- nugetSource: URL do feed
- nugetUsername / nugetPassword: credenciais (use secrets)

Go
- go: ativa build Go (toggle)
- goBuildCmd: override total
- goMain: pacote/dir principal (ex.: ./cmd/api). Vazio => compila todos packages main
- goOS / goArch: GOOS/GOARCH
- goCGOEnabled: 0|1 (default: 0)
- goLDFlags: flags para -ldflags (mantemos símbolos por padrão)
- goTags: build tags
- goOutputDir: saída do pacote (default: dist/veracode-go)
- goBinaryName: nome do binário (quando único main)
- goAdditionalArgs: args extras `go build`
- goModVendor: executar `go mod vendor` (default: false)
- goGenerate: executar `go generate ./...` (default: false)
- goRace: habilitar `-race` (default: false)

Java (puro)
- java: ativa build Java (toggle, quando não usa Maven/Gradle)
- javaBuildCmd: override total
- javaSourceDir: diretório de fontes (default: src/main/java)
- javaResourcesDir: diretório de resources (default: src/main/resources)
- javaLibDir: dependências .jar opcionais (default: lib)
- javaJarName: nome do JAR (default: app.jar)
- javaMainClass: Main-Class opcional
- javaOutputDir: saída do pacote (default: dist/veracode-java)
- javaAdditionalJavacArgs / javaAdditionalJarArgs

## Outputs
- upload_guid: GUID do build na plataforma Veracode (resolvido via getbuildlist pelo `version` enviado)

## Integrações Veracode (como funciona)
- SCA (Agent-based)
  - Usa `veracode/veracode-sca@v2` (ou script com `ci.sh`)
  - Token: `scaToken` => `SRCCLR_API_TOKEN`
- Upload & Scan (Plataforma)
  - Usa `veracode/veracode-uploadandscan-action@0.2.9`
  - `appname`: `Github - <owner>/<repo>`, `createprofile=true`
  - `version`: `Scan from Github job: <run_id>-<run_number>-<attempt>`
  - `filepath`: artefato resolvido (build/AP/artefato manual)
  - Depois o Hub consulta o Java API Wrapper para capturar o `upload_guid`
- Pipeline Scan
  - Usa `veracode/Veracode-pipeline-scan-action@v1.0.20`
  - `file`: artefato resolvido; apenas logs (sem arquivos)
- IaC/Container/Secrets
  - Executa via Veracode CLI (instalada automaticamente em Linux/macOS quando `enableIAC=true`)
  - Utiliza VID/VKEY; saída apenas no console
- Auto Packager (AP)
  - Requer a Veracode CLI; empacota em `veracode_package.zip`
  - O resolver usa esse zip quando presente

## Builds suportados e artefatos gerados
- Maven → `dist/veracode-maven/veracode-maven-package.zip`
- Gradle → `dist/veracode-gradle/veracode-gradle-package.zip`
- Kotlin (Gradle) → `dist/veracode-kotlin/veracode-kotlin-package.zip`
- .NET (publish + símbolos) → `dist/veracode-dotnet/veracode-dotnet-package.zip`
- Go (binários + go.mod/sum + configs) → `dist/veracode-go/veracode-go-package.zip`
- Java puro (javac/jar + libs/resources) → `dist/veracode-java/veracode-java-package.zip`
- Artefato manual → definido por `artifactName`

## Exemplo de uso (seleção)

Somente SCA
- uses: owner/veracode-integration-hub@v1
  with:
    enableSCA: "true"
    scaToken: ${{ secrets.SRCCLR_API_TOKEN }}

Upload & Scan com Auto Packager (CLI)
- uses: owner/veracode-integration-hub@v1
  with:
    enableUS: "true"
    enableAP: "true"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}

Maven + Upload & Scan
- uses: owner/veracode-integration-hub@v1
  with:
    enableUS: "true"
    maven: "true"
    mavenGoals: "-B -DskipTests package"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}

Gradle + Upload & Scan
- uses: owner/veracode-integration-hub@v1
  with:
    enableUS: "true"
    gradle: "true"
    gradleTasks: "assemble -x test"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}

Kotlin + Upload & Scan
- uses: owner/veracode-integration-hub@v1
  with:
    enableUS: "true"
    kotlin: "true"
    kotlinTasks: "assemble -x test"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}

.NET + Upload & Scan (com restore e RID)
- uses: owner/veracode-integration-hub@v1
  with:
    enableUS: "true"
    dotnet: "true"
    dotnetRestore: "true"
    dotnetSolution: "MyApp.sln"
    dotnetRuntime: "linux-x64"
    dotnetConfiguration: "Release"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}

Go + Upload & Scan
- uses: owner/veracode-integration-hub@v1
  with:
    enableUS: "true"
    go: "true"
    goMain: "./cmd/api"
    goOS: "linux"
    goArch: "amd64"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}

Java puro + Upload & Scan
- uses: owner/veracode-integration-hub@v1
  with:
    enableUS: "true"
    java: "true"
    javaMainClass: "com.example.Main"
    javaJarName: "app.jar"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}

Artefato manual + Upload & Scan
- uses: owner/veracode-integration-hub@v1
  with:
    enableUS: "true"
    artifact: "true"
    artifactName: "dist/app.zip"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}

Pipeline Scan
- uses: owner/veracode-integration-hub@v1
  with:
    enablePS: "true"
    maven: "true"
    mavenGoals: "-B -DskipTests package"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}

IaC/Container/Secrets
- uses: owner/veracode-integration-hub@v1
  with:
    enableIAC: "true"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}

## Requisitos e Secrets
- Adicione em Settings > Secrets and variables > Actions:
  - VERACODE_API_ID e VERACODE_API_KEY (para US/PS/IaC)
  - SRCCLR_API_TOKEN (para SCA)
- Runners:
  - A instalação automática da Veracode CLI funciona em Linux/macOS (Auto Packager e IaC). Em Windows, use ubuntu-latest.

## Logs e Outputs
- Logs legíveis, com emojis: ⚙️, ✅, ❌, 📦, 📤
- Nenhum relatório/JSON salvo — apenas console
- upload_guid exibido e exposto como output quando `enableUS=true`

## Licença e Créditos
- Licença Proprietária: uso restrito a usuários autorizados. Consulte o arquivo `LICENSE`.
- Desenvolvido por: https://github.com/JuanCunhaa — https://www.linkedin.com/in/juan--cunha
