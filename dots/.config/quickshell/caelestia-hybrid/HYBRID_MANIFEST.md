# Caelestia Hybrid — Manifesto de Proveniência e Customizações

Este diretório (`dots/.config/quickshell/caelestia-hybrid`) contém o frontend Quickshell **Caelestia Hybrid**, adaptado para operar em conjunto com o **illogical-impulse (`end-4`)** sob o mesmo ambiente Hyprland.

## 1. Atribuição Upstream e Licença

* **Projeto Original:** [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
* **Revisão Fixada (`UPSTREAM_REVISION`):** `454f46da16ae75cc57f34adf48dea74db0fa5175` (`v2.5.0-6-g454f46da`)
* **Licença:** GNU General Public License v3.0 (`GPL-3.0-only`, preservada em `./LICENSE`)

> **Nota sobre não duplicação:** Os diretórios de código C++ (`plugin/`, `extras/`), empacotamento Nix (`nix/`, `flake.*`) e ferramentas de lint do repositório `caelestia-dots/shell` **não** são duplicados aqui. O plugin C++/QML nativo (`Caelestia.*`) é compilado sob demanda a partir do commit fixado via `sdata/dist-arch/illogical-impulse-caelestia-plugin/PKGBUILD`.

---

## 2. Arquivos Próprios (Desenvolvidos Localmente)

| Arquivo | Finalidade |
| :--- | :--- |
| `UPSTREAM_REVISION` | Hash SHA-1 do commit base do `caelestia-dots/shell`. |
| `HYBRID_MANIFEST.md` | Este manifesto de rastreabilidade. |
| `scripts/end4-theme-bridge.sh` | Sincroniza o wallpaper e converte a paleta Material You do `end-4` (`colors.json` em `snake_case`) para o formato `camelCase` esperado pelo Caelestia (`scheme.json`). |
| `scripts/video-wallpaper-sync.sh` | Monitora wallpapers em vídeo/GIF definidos no `end-4`, desativa o fundo estático do Caelestia (`wallpaperEnabled: false`) e controla o `mpvpaper`. |
| `scripts/nightlight.sh` | Controle e leitura de estado de temperatura de cor via `hyprctl hyprsunset`. |
| `scripts/caelestia-runtime-binds.sh` | Helper de atualização de estado do frontend (`ui-switch/current`) e reload do Hyprland. |
| `modules/VideoWallpaperBridge.qml` | Gerencia o processo `video-wallpaper-sync.sh watch` acoplado ao ciclo de vida do `caelestia-hybrid`. |
| `modules/bar/components/UiFrontendSwitchButton.qml` | Botão na barra vertical do Caelestia para alternar de volta ao `end-4` via `ui-switch.sh end4`. |
| `modules/bar/components/DashboardButton.qml` | Botão na barra para acionar o Dashboard (sincronizado a `Config.dashboard.enabled`). |
| `modules/bar/components/SidebarButton.qml` | Botão na barra para acionar a Sidebar/Notificações (sincronizado a `Config.sidebar.enabled`). |
| `services/BarEntries.qml` | Singleton para leitura e escrita reativa de botões e ícones da barra de tarefas (`Config.bar.entries` e `Config.bar.statusIcons`). |
| `modules/bar/popouts/StatusCenter.qml` | Popout unificado **Quick controls** na barra reativo a `Config.utilities.cards` e `Config.utilities.quickToggles` (Wi-Fi, Bluetooth, Microfone, Night Light, Game Mode, DND, Keep Awake, VPN, Settings e gravador nativo). |

---

## 3. Arquivos do Upstream Modificados Localmente

| Arquivo | Alteração Aplicada |
| :--- | :--- |
| `shell.qml` | Instancia `VideoWallpaperBridge {}` e remove `IdleMonitors` (o bloqueio por inatividade é centralizado via `hypridle` + `rice-lock`). |
| `modules/bar/Bar.qml` | Adiciona `UiFrontendSwitchButton`, `DashboardButton` e `SidebarButton` na barra principal com filtros reativos a `Config`. |
| `modules/bar/components/Clock.qml` | Altera ícone para `schedule`. |
| `modules/bar/components/OsIcon.qml` | Ajusta dimensões interativas (`implicitWidth`/`implicitHeight`), suporte a `StateLayer` e cursor pointer para disparar o Launcher. |
| `modules/bar/components/StatusIcons.qml` | Substitui o indicador textual de `kbLayout` pelo gatilho do popout `statuscenter` (ícone `tune`) condicionado a `Config.utilities.enabled`. |
| `modules/bar/popouts/ClipWrapper.qml` | Propaga a propriedade `screenState` para o `StatusCenter`. |
| `modules/bar/popouts/Content.qml` | Registra o `Popout` `statuscenter` instanciando `StatusCenter`. |
| `modules/bar/popouts/Wrapper.qml` | Propaga `screenState` para `Content`. |
| `modules/drawers/Panels.qml` | Passa `root.screenState` ao `popoutsWrapper`. |
| `modules/nexus/pages/AboutPage.qml` | Substitui o logo e título do Caelestia pelo emblema animado do Redshift OS (`Logo.qml`) e identificação do sistema (`SysInfo.osPrettyName`). |
| `modules/nexus/common/AnimatedLogo.qml` | Converte o componente legado do logo Caelestia em wrapper animado do emblema Redshift OS. |
| `modules/nexus/pages/panels/DashboardPanel.qml` | Adiciona toggle para exibir/ocultar botão do Dashboard na barra de tarefas (`BarEntries`). |
| `modules/nexus/pages/panels/LauncherPanel.qml` | Adiciona toggle para exibir/ocultar ícone do Launcher na barra de tarefas (`BarEntries`). |
| `modules/nexus/pages/panels/SidebarPanel.qml` | Adiciona controle `Show on hover` (`Config.sidebar.showOnHover`) e toggle para exibir/ocultar botão na barra de tarefas (`BarEntries`). |
| `modules/nexus/pages/panels/TaskbarPanel.qml` | Adiciona seção `Panel buttons` com toggles para Launcher, Dashboard, Sidebar e botão de alternância end-4/Caelestia (`BarEntries`). |
| `modules/nexus/pages/panels/UtilitiesPanel.qml` | Adiciona toggle para exibir/ocultar ícone de utilidades/quick controls na barra de tarefas (`BarEntries`). |
| `modules/session/Content.qml` | Ajusta reprodução contínua (`playing: true`, `cache: false`) do GIF da tela de sessão. |
| `modules/Shortcuts.qml` | Mantém atalhos de alternância para dashboard, sidebar e utilities sincronizados. |
| `modules/utilities/Wrapper.qml` | Reativa drawer de utilidades condicionado a `screenState.utilities && Config.utilities.enabled`. |
| `modules/utilities/cards/Toggles.qml` | Adiciona toggle `nightLight` integrado ao `hyprsunset` e `XDG_STATE_HOME/caelestia/nightlight`. |
| `services/Colours.qml` | Redireciona `setMode()` para `scripts/end4-theme-bridge.sh --mode <mode> --noswitch`. |
| `components/controls/StyledSlider.qml` | Adapta `onPositionChanged`/`onReleased` para mapear a posição interativa na escala do slider (`root.from` até `root.to`). |
| `modules/nexus/common/SliderRow.qml` | Expõe propriedades `from` e `to`, delega limites ao `StyledSlider` e limita rotação da roda do mouse até `root.to`. |
| `modules/nexus/pages/AudioPage.qml` | Vincula sliders de áudio de saída e entrada a `GlobalConfig.services.maxVolume` (suportando até 150%). |
| `modules/nexus/pages/audio/AppVolumes.qml` | Vincula sliders de volume por aplicação a `GlobalConfig.services.maxVolume` (suportando até 150%). |
| `modules/bar/popouts/AudioPopout.qml` | Vincula o slider de volume do popout da barra a `GlobalConfig.services.maxVolume` (suportando até 150%). |
| `services/Wallpapers.qml` | Redireciona `setWallpaper()` e `setRandom()` para `scripts/end4-theme-bridge.sh`, removendo dependência da CLI `caelestia`. |
| `assets/kurukuru.gif` | Asset animado personalizado para a tela de sessão. |
