# Veracode Integration Engine

Composite Action que centraliza integracoes do Veracode: SCA (Dependency Scanning), Upload & Scan (plataforma), Pipeline Scan e IaC/Container/Secrets. A acao padroniza builds e empacotamento, valida entradas antes de executar e publica apenas logs no console (sem arquivos de relatorio), facilitando a adocao do Veracode em multiplos tipos de projeto.

Principais recursos
- Um hub unico para SCA, Upload & Scan, Pipeline Scan e IaC.
- Validacao de inputs e secrets logo no inicio, com instrucoes de correcao.
- Instalacao automatica da Veracode CLI quando necessario (Auto Packager e IaC) em Linux/macOS.
- Builds opcionais por linguagem com empacotamento padronizado (gera um .zip por linguagem).
- Integracao com actions oficiais do Veracode (SCA, Pipeline, Upload & Scan).
- upload_guid real capturado apos o Upload & Scan.

## Parametros (Inputs)

- enableSCA, enableUS, enablePS, enableIAC, enableAP
- workingDirectory (default: "."), debug (default: "false")
- artifact (default: "false"), artifactName
- veracodeApiId, veracodeApiKey, scaToken, iacToken

- Java runtime: javaVersion (default: 17), javaDistribution (default: temurin)

- Maven:
  - maven (toggle), mavenCmd, mavenWrapperPath (default: ./mvnw), mavenGoals (default: -B -DskipTests package)
  - mavenProjectDir (default: .), mavenOptions (default: --no-transfer-progress), mavenOutputDir (default: dist/veracode-maven)

- Gradle:
  - gradle (toggle), gradleCmd, gradleWrapperPath (default: ./gradlew), gradleTasks (default: assemble -x test)
  - gradleProjectDir (default: .), gradleOptions (default: --no-daemon), gradleIncludeDists (default: true)
  - gradleOutputDir (default: dist/veracode-gradle)

- Kotlin (via Gradle):
  - kotlin (toggle), kotlinCmd, kotlinWrapperPath, kotlinTasks, kotlinProjectDir, kotlinOptions, kotlinIncludeDists, kotlinOutputDir (default: dist/veracode-kotlin)

- .NET:
  - dotnet (toggle), dotnetVersion (default: 7.0.x), dotnetBuildCmd (default: dotnet build -c Release)
  - dotnetRestore (default: false), dotnetRestoreCmd (default: dotnet restore)
  - dotnetProject, dotnetSolution, dotnetConfiguration (default: Release), dotnetRuntime (RID)
  - dotnetSelfContained (default: false), dotnetPublishSingleFile (default: false), dotnetIncludeSymbols (default: true)
  - dotnetOutputDir (default: dist/veracode-dotnet), dotnetAdditionalArgs
  - nugetConfigPath, nugetSource, nugetUsername, nugetPassword

- Go:
  - go (toggle), goVersion (default: 1.21.x), goBuildCmd (default: go build ./...)
  - goMain, goOS, goArch, goCGOEnabled (default: 0), goLDFlags, goTags
  - goOutputDir (default: dist/veracode-go), goBinaryName, goAdditionalArgs
  - goModVendor (default: false), goGenerate (default: false), goRace (default: false)

- Java (puro):
  - java (toggle), javaBuildCmd, javaSourceDir (default: src/main/java), javaResourcesDir (default: src/main/resources)
  - javaLibDir (default: lib), javaJarName (default: app.jar), javaMainClass, javaOutputDir (default: dist/veracode-java)
  - javaAdditionalJavacArgs, javaAdditionalJarArgs

## Outputs
- upload_guid: GUID do build na plataforma Veracode (exposto apos Upload & Scan)

## Builds suportados e artefatos gerados
- Maven -> dist/veracode-maven/veracode-maven-package.zip
- Gradle -> dist/veracode-gradle/veracode-gradle-package.zip
- Kotlin (Gradle) -> dist/veracode-kotlin/veracode-kotlin-package.zip
- .NET (publish + simbolos) -> dist/veracode-dotnet/veracode-dotnet-package.zip
- Go (binarios + go.mod/sum + configs) -> dist/veracode-go/veracode-go-package.zip
- Java puro (javac/jar + libs/resources) -> dist/veracode-java/veracode-java-package.zip
- Artefato manual -> definido por artifactName

## Exemplo de uso (selecao)

Somente SCA
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enableSCA: "true"
    scaToken: ${{ secrets.SRCCLR_API_TOKEN }}
    debug: "false"
```

Upload & Scan com Auto Packager (CLI)
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enableUS: "true"
    enableAP: "true"
    javaVersion: "17"
    javaDistribution: "temurin"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}
```

Maven + Upload & Scan
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enableUS: "true"
    maven: "true"
    mavenGoals: "-B -DskipTests package"
    mavenOptions: "--no-transfer-progress"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}
```

Gradle + Upload & Scan
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enableUS: "true"
    gradle: "true"
    gradleTasks: "assemble -x test"
    gradleIncludeDists: "true"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}
```

Kotlin + Upload & Scan
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enableUS: "true"
    kotlin: "true"
    kotlinTasks: "assemble -x test"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}
```

.NET + Upload & Scan (com restore e RID)
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enableUS: "true"
    dotnet: "true"
    dotnetVersion: "7.0.x"
    dotnetRestore: "true"
    dotnetSolution: "MyApp.sln"
    dotnetRuntime: "linux-x64"
    dotnetConfiguration: "Release"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}
```

Go + Upload & Scan
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enableUS: "true"
    go: "true"
    goVersion: "1.21.x"
    goMain: "./cmd/api"
    goOS: "linux"
    goArch: "amd64"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}
```

Java puro + Upload & Scan
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enableUS: "true"
    java: "true"
    javaMainClass: "com.example.Main"
    javaJarName: "app.jar"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}
```

Artefato manual + Upload & Scan
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enableUS: "true"
    artifact: "true"
    artifactName: "dist/app.zip"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}
```

Pipeline Scan
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enablePS: "true"
    artifact: "true"
    artifactName: "dist/app.zip"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}
```

IaC/Container/Secrets
```yaml
- uses: JuanCunhaa/Veracode-Integration-Engine@main
  with:
    enableIAC: "true"
    veracodeApiId: ${{ secrets.VERACODE_API_ID }}
    veracodeApiKey: ${{ secrets.VERACODE_API_KEY }}
```

## Requisitos e Secrets
- Permissoes recomendadas (adicione ao workflow/job):
```yaml
permissions:
  contents: read
```
- Adicione em Settings > Secrets and variables > Actions:
  - VERACODE_API_ID e VERACODE_API_KEY (para US/PS/IaC)
  - SRCCLR_API_TOKEN (para SCA)
- Runners:
  - A instalacao automatica da Veracode CLI funciona em Linux/macOS (Auto Packager e IaC). Em Windows, use ubuntu-latest.

## Logs e Outputs
- Logs legiveis, apenas no console (sem salvar arquivos)
- upload_guid exibido e exposto como output quando `enableUS=true`

## Licenca e Creditos
- Licenca Proprietaria: uso restrito a usuarios autorizados. Consulte o arquivo `LICENSE`.
- Desenvolvido por: https://github.com/JuanCunhaa
