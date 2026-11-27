# Redshift Doctor e Redshift Guard 2.0

O Guard reúne a supervisão da interface do Hyprland, o monitoramento do runtime Arch e a recompilação assistida. O Doctor consulta o Guard e disponibiliza os diagnósticos em texto e JSON.

## Instalação e sessão

`./setup install` instala as dependências e copia o Guard, o Doctor, os atalhos, o serviço de usuário e as receitas de recompilação para seus diretórios XDG. O passo de arquivos, em ambos os modos de cópia, valida a instalação e o ABI. Nos perfis híbridos, o instalador também executa a verificação de prontidão do Caelestia já existente. Se uma incompatibilidade for encontrada, o instalador informa o aviso de runtime e o diagnóstico correspondente.

O Hyprland inicia `redshift-ui-watchdog.service` com as variáveis da sessão Wayland. Em ambientes sem um gerenciador systemd de usuário acessível, inicia o watchdog diretamente. O perfil `minimal` e instalações com `--skip-caelestia` usam end-4. Os perfis `hybrid` e `complete` habilitam os dois frontends.

## Recuperação

O watchdog testa o IPC do frontend mesmo quando o processo ainda aparece na lista do Quickshell. O reinício e o UI Switch usam o mesmo lock, inclusive durante a validação do processo novo. O Guard mantém as janelas do usuário e pausa a recuperação quando detecta `hyprlock` ou o estado bloqueado no logind.

Após três falhas do frontend em 60 segundos, o Guard tenta o outro frontend disponível. Com o limite de tentativas em cinco minutos atingido, aguarda a janela avançar. Se o frontend alternativo estiver indisponível ou falhar, pausa a recuperação automática. Um reinício manual ou uma troca bem-sucedida no UI Switch permite retomar as tentativas.

- **Super + Ctrl + Shift + B** executa a recuperação conservadora e verifica o papel de parede.
- **Ctrl + Super + R** solicita o reinício do frontend e permite nova tentativa após uma pausa.
- Ambos são atalhos do Hyprland e continuam disponíveis quando o Quickshell encerra.

```bash
redshift-ui-recover --status
redshift-ui-recover --check
redshift-ui-recover --logs 50
journalctl --user -u redshift-ui-watchdog.service -b
```

Os logs de recuperação e inicialização do frontend ficam em `${XDG_STATE_HOME:-$HOME/.local/state}/redshift-os/`. O serviço encerra quando o Hyprland deixa de responder.

## Atalhos do end-4

- **Super + W** abre o navegador pelo Hyprland, inclusive durante a recuperação do Quickshell. A instalação padrão usa o primeiro navegador disponível na ordem do launcher e pode usar a associação HTTPS para instalações como Flatpak, quando `gtk-launch` está disponível. A variável `browser` em `hypr/custom/variables.lua` continua disponível para escolher outro comando.
- **Super + V** abre ou fecha o histórico do Cliphist nas famílias `ii` e `waffle`. Se o painel estiver indisponível, o fuzzel oferece os itens persistidos. Uma instalação nova mostra o estado vazio até que algum conteúdo seja copiado.

## Atualizações e ABI

O pacote `illogical-impulse-quickshell-git` instala `redshift-doctor-check.hook` em `/usr/share/libalpm/hooks` e depende de `pacman-contrib`. Em transações envolvendo Qt, Quickshell, Caelestia e bibliotecas selecionadas, o hook atualiza `/var/lib/redshift-guard/pacman-transaction` após o fim da transação. Cada sessão compara o marcador e as versões instaladas com seu último diagnóstico. Assim, uma verificação continua pendente mesmo que a atualização ocorra fora da sessão gráfica.

O Guard verifica a compatibilidade Qt do Quickshell e usa `ldd -r` para identificar bibliotecas ausentes e símbolos não resolvidos no Quickshell, nas bibliotecas nativas do Caelestia e na libcava. Isso detecta, por exemplo, quando a libcava ainda exige uma versão de sndio que o sistema atualizou. O UI Switch faz a verificação antes de iniciar Caelestia e confirma o IPC antes de concluir a troca.

A troca, o Doctor e a recuperação procuram uma instalação completa dos módulos nativos Caelestia nos caminhos QML do Qt, do sistema e do usuário. `CAELESTIA_QML_PATH` pode indicar a raiz do plugin para uma instalação personalizada. A verificação de ABI inclui os submódulos importados pela interface.

A cada seis horas de consulta bem-sucedida, o Guard usa `checkupdates` com uma base temporária separada para listar atualizações dos repositórios configurados no Pacman. Em caso de falha da consulta, registra o erro e aguarda 15 minutos antes de repetir. As últimas verificações e a lista de atualizações ficam no estado XDG do usuário.

```bash
redshift-doctor --check guard
redshift-doctor --check guard --json
redshift-doctor --check ui
redshift-doctor --check caelestia
```

O Doctor retorna `0` quando os componentes verificados estão íntegros, `1` para erro e `2` para aviso ou manutenção pendente.

## Recompilação assistida

Atualize o Arch integralmente antes de recompilar. Os comandos usam as receitas distribuídas pelo instalador, inclusive quando executados fora do checkout.

```bash
redshift-doctor --repair quickshell
redshift-doctor --repair caelestia
redshift-doctor --repair guard       # Quickshell e Caelestia, se instalado
```

O Guard solicita confirmação, compila como usuário comum em um diretório temporário e só chama `sudo pacman -U` depois que todas as compilações selecionadas terminam. Em seguida, verifica o ABI instalado. `--yes` confirma a recompilação. Use Ctrl + Super + R para carregar o runtime recompilado.

A recompilação cobre os pacotes próprios do Redshift. Se o diagnóstico localizar o problema em libcava, sndio ou outra dependência externa, corrija o pacote pelo gerenciador correspondente e rode o diagnóstico novamente. A alternância restaura a interface disponível dentro da sessão. As versões instaladas dos pacotes são administradas pelo Pacman.
