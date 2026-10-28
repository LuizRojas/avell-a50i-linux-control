# Avell Linux Control Center

**Control Center nativo para Linux em notebooks Avell/Clevo** que usam a
interface ACPI `CLV0001` / `\_SB.DCHU` (Insyde DCHU).

O projeto porta o **Control Center 3.0** do Windows (Clevo/Insyde) por
engenharia reversa e entrega três peças: um driver de kernel (DKMS), a CLI
`avellctl` e um app GTK4/libadwaita. O núcleo é genérico: o driver pergunta
ao firmware o que a máquina tem (ventoinhas, tipo de teclado) e só expõe
isso. Diferenças entre modelos ficam numa tabela de quirks por DMI, sem
duplicar código.

> 🇺🇸 *Native Linux replacement for the Avell/Clevo Control Center on
> machines exposing the `CLV0001` DCHU ACPI interface: kernel driver (power
> profiles, fans, RGB keyboard, battery charge limit, Fn hotkeys) + GTK4 app.*

> ⚠️ Projeto **não oficial**, sem vínculo com a Avell ou a Clevo. Use por sua
> conta e risco.

## O que foi portado

| Componente do Control Center (Windows) | Equivalente no Linux |
|---|---|
| CC30: modos de energia (Silencioso, Economia, Entretenimento, Desempenho) | `platform_profile` → menu de energia do GNOME + app |
| FanSpeedSetting: RPM, temperatura, duty, modos, anti-poeira | `hwmon` (`sensors`) + app / `avellctl fan`, `antidust` |
| LedKeyboardSetting: luz branca ou RGB, cor, brilho, efeitos | LED `avell::kbd_backlight` + app (efeitos gerados pelo driver no RGB de zona única) |
| BatteryUtility (FlexiCharger): limite de carga | `charge_control_*_threshold` ("Preservar saúde da bateria" do GNOME) + app |
| DCHUService + FnKey: teclas Fn | tratadas no driver / dispositivo de entrada |
| AcpiBridge + InsydeDCHU | driver `avell_dchu` (`acpi_evaluate_dsm`) |

Drivers do restante do hardware do pacote Windows (vídeo, Wi-Fi, áudio etc.)
já têm equivalente nativo no kernel: veja [docs/DRIVERS.md](docs/DRIVERS.md).

## Modelos

| Modelo | Status | BIOS / EC | Teclado | Sistema |
|---|---|---|---|---|
| Avell A50i (HYB A50i) | ✅ portado e testado | 1.07.01TBN / 1.07.03 | RGB zona única (tipo 6) | Debian 13, kernel 6.12, GNOME 48 |
| Avell ION A50 | 🔎 a verificar | — | — | — |

Qualquer Avell/Clevo com `CLV0001` pode funcionar. Confira com
`ls /sys/bus/acpi/devices | grep CLV0001`. Para adicionar seu modelo, abra uma
issue com a saída de `avellctl`, `sudo dmidecode -s system-product-name -s bios-version`
e `sudo dmesg | grep avell`.

### Ajustes por modelo (quirks)

O driver lê do firmware o tipo de teclado e o número de ventoinhas. Se a sua
máquina reportar algo errado, teste sem recompilar:

```bash
sudo modprobe -r avell_dchu
sudo modprobe avell_dchu force_kbd_type=6 force_fan_count=2
```

Se funcionar, abra um PR adicionando uma entrada `DMI_MATCH()` em
`avell_quirk_table` (`driver/avell_dchu.c`). O driver imprime no `dmesg`
a linha `DMI: <fabricante> <produto>, BIOS <versão>` para você copiar.

## Instalar

Requisitos: Debian/Ubuntu (`apt`) ou Arch Linux e derivados (`pacman`); o
script instala `dkms`, os headers do kernel em execução e GTK4/libadwaita. Com Secure Boot ativo, a chave MOK do DKMS precisa estar
registrada.

```bash
git clone https://github.com/LuizRojas/avell-linux-control-center.git
cd avell-linux-control-center
./install.sh
```

Isso compila o módulo via DKMS (recompila sozinho a cada atualização do
kernel), instala `avellctl`, o app **Avell Control Center**, a regra polkit
(o usuário local ativo altera o hardware sem senha) e o serviço que restaura
suas configurações no boot.

Remover: `./uninstall.sh`

## Usar

Abra **Avell Control Center** no menu de aplicativos, ou use o terminal:

```bash
avellctl                       # estado + sensores
avellctl profile performance   # quiet | low-power | balanced | performance
avellctl fan silent            # auto | silent | max | maxq
avellctl kbd 3                 # brilho do teclado
avellctl color 00aaff          # cor (RGB)
avellctl effect cycle          # static breathe cycle flash random (+ wave dance tempo no 3 zonas)
avellctl charge 70 90          # carregar abaixo de 70%, parar em 90%
sudo avellctl raw 0x0d         # chamada _DSM bruta (diagnóstico)
```

## Estrutura

```
driver/      módulo de kernel avell_dchu (DKMS)
avell_cc/    biblioteca, CLI, helper privilegiado e app GTK4/libadwaita
data/        polkit, systemd, .desktop
docs/        PROTOCOLO.md (engenharia reversa) e DRIVERS.md (drivers do Windows → Linux)
```

## Como funciona

Toda a pilha do Windows (`AcpiBridge.sys` + `InsydeDCHU.dll` + apps .NET) se
resume a uma chamada ACPI:

```
\_SB.DCHU._DSM(93f224e4-fbdc-4bbf-add6-db71bdc0afad, 0, <comando>, Package { Buffer(256) })
```

O driver faz essa mesma chamada com `acpi_evaluate_dsm()` e expõe tudo pelas
interfaces padrão do kernel. A tabela completa de comandos e os detalhes estão
em [docs/PROTOCOLO.md](docs/PROTOCOLO.md).

## Contribuir

- O desenvolvimento acontece na `develop`; a `main` é protegida e só recebe
  releases por PR.
- Abra o PR contra a `develop` usando o template do repositório
  (título `[FEAT]`, `[FIX]`, `[DOCS]`…).
- Mudanças no driver devem informar modelo, BIOS e kernel em que foram testadas.

## Segurança

O driver só emite as chamadas `_DSM` que o Control Center oficial emite. O
dispositivo `/dev/avell-dchu` (chamadas brutas) exige root (`CAP_SYS_ADMIN`).
O helper do polkit aceita apenas uma lista fechada de operações e valores.

Este repositório não contém nenhum binário, instalador ou código do software
original; só código próprio e a documentação do protocolo, para
interoperabilidade.

## Licença

GPL-2.0-or-later. Veja [LICENSE](LICENSE).
