# docker-drachtio-freeswitch-mrf

This branch builds a custom Debian 12 FreeSWITCH image for drachtio and jambonz media workloads. It is not the slim upstream-style image described by the old README.

What is actually in this branch today:

- a multi-stage Docker build that compiles FreeSWITCH from source
- jambonz-specific modules and source patches pulled from `deployment-tools/packer`
- runtime configuration overlaid from `files/`
- Node.js 18 plus a global `axios` install inside the final image
- `awscli`, `s3fs`, `rsyslog`, and a background watcher that monitors `/var/pres3fs`
- additional infrastructure assets for packer, terraform, and cloudformation deployments

## Repository layout

| Path | Purpose |
| --- | --- |
| `Dockerfile` | Multi-stage image build for the container described in this README. |
| `files/` | Runtime entrypoint, FreeSWITCH XML, SIP profiles, and dialplans copied into the final image. |
| `deployment-tools/packer/` | Build scripts, patches, modules, and machine-image templates. The Docker build depends on these files. |
| `deployment-tools/terraform/gcp/mini/` | Terraform for a jambonz mini deployment on GCP. |
| `deployment-tools/cloudformation/` | CloudFormation templates for jambonz deployments. |
| `deployment-tools/SSH_Install.md` | Notes for direct SSH-based jambonz installation onto a VM or bare-metal host. |

## How this branch builds the image

The root `Dockerfile` does the following:

1. Starts from `debian:12` unless you override `DISTRO_IMAGE`.
2. Copies `deployment-tools/packer/files/*` and selected install scripts into the build stage.
3. Runs `deployment-tools/packer/scripts/install_freeswitch.sh` to build FreeSWITCH and jambonz media modules from source.
4. Copies the built FreeSWITCH tree into a smaller runtime stage.
5. Overlays the runtime configuration from `files/`.
6. Installs the custom entrypoint and monitoring scripts.

This is important because the effective build inputs for this branch are:

- `Dockerfile`
- `deployment-tools/packer/scripts/install_freeswitch.sh`
- `deployment-tools/packer/files/*`
- `files/*`

The old `build-locally.sh` flow referenced by earlier documentation does not exist in this branch.

## Version reality for this branch

The checked-in `.env` and `CHANGELOG.md` do not reflect the exact versions currently used by the Docker build. The actual source of truth is `deployment-tools/packer/scripts/install_freeswitch.sh`.

Current version pins used by the Docker build:

| Component | Value used by the build |
| --- | --- |
| Base distro | `debian:12` |
| FreeSWITCH | `v1.10.10` |
| `freeswitch-modules` bundle | `2.5.10` |
| gRPC | `v1.57.0` |
| AWS SDK for C++ | `1.11.500` |
| libwebsockets | `v4.3.3` |
| Azure Speech SDK | `1.45.0` |
| Houndify SDK | `2.0.0` |
| ONNX Runtime | `1.22.0` |
| Node.js runtime in final image | `18` |

If you change versions in `.env` without also updating the Docker build inputs above, the image will not change.

## Build the image

`TARGETARCH` is required by this Dockerfile. Supported values are `amd64` and `arm64`.

Build natively for `amd64`:

```bash
docker build \
  --build-arg TARGETARCH=amd64 \
  -t local/drachtio-freeswitch-mrf:amd64 .
```

Build natively for `arm64`:

```bash
docker build \
  --build-arg TARGETARCH=arm64 \
  -t local/drachtio-freeswitch-mrf:arm64 .
```

Cross-build with `buildx`:

```bash
docker buildx build \
  --platform linux/amd64 \
  --build-arg TARGETARCH=amd64 \
  -t local/drachtio-freeswitch-mrf:amd64 \
  --load .
```

Notes:

- the build is heavy and requires network access because it clones and compiles multiple upstream projects
- the build stage pulls a large dependency set and can take a while even on a fast machine
- only `amd64` and `arm64` are accepted; any other `TARGETARCH` exits with an error

## Run the image

The image sets:

- `ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]`
- `CMD ["freeswitch"]`

That means:

- `docker run image` starts FreeSWITCH with default settings
- if you want to pass runtime flags handled by the entrypoint, `freeswitch` must remain the first argument
- `docker run image --sip-port 5090` is wrong for this image
- `docker run image freeswitch --sip-port 5090` is correct

### Minimal local run

```bash
docker run -d --rm \
  --name fs-mrf \
  -p 5080:5080/udp \
  -p 5080:5080/tcp \
  -p 5081:5081/tcp \
  -p 8021:8021/tcp \
  -p 25000-25049:25000-25049/udp \
  -v "$(pwd)/log:/usr/local/freeswitch/log" \
  -v "$(pwd)/recordings:/usr/local/freeswitch/recordings" \
  local/drachtio-freeswitch-mrf:amd64 \
  freeswitch --rtp-range-start 25000 --rtp-range-end 25049
```

### Linux host-network run

If you are deploying on Linux and want FreeSWITCH to bind directly to the host stack:

```bash
docker run -d --rm \
  --name fs-mrf \
  --net=host \
  -v /srv/fs-log:/usr/local/freeswitch/log \
  -v /srv/fs-recordings:/usr/local/freeswitch/recordings \
  local/drachtio-freeswitch-mrf:amd64 \
  freeswitch
```

### Open a console in the running container

Default ESL password:

```bash
docker exec -it fs-mrf fs_cli -p 'JambonzR0ck$'
```

Shell access:

```bash
docker exec -it fs-mrf bash
```

## Runtime flags handled by `entrypoint.sh`

The entrypoint mutates FreeSWITCH XML before launch. These are the supported flags:

| Flag | Default | Effect |
| --- | --- | --- |
| `--sip-port`, `-s` | `5080` | Updates `sip_port` in `conf/vars_diff.xml`. |
| `--tls-port`, `-t` | `5081` | Updates `tls_port` in `conf/vars_diff.xml`. |
| `--event-socket-port`, `-e` | `8021` | Rewrites the ESL listen port in `autoload_configs/event_socket.conf.xml`. |
| `--password`, `-p` | `JambonzR0ck$` | Rewrites the ESL password in `autoload_configs/event_socket.conf.xml`. |
| `--rtp-range-start`, `-a` | `25000` | Rewrites `rtp-start-port` in `autoload_configs/switch.conf.xml`. |
| `--rtp-range-end`, `-z` | `39000` | Rewrites `rtp-end-port` in `autoload_configs/switch.conf.xml`. |
| `--ext-sip-ip` | local IP | Updates `ext_sip_ip` in `conf/vars_diff.xml`. |
| `--ext-rtp-ip` | local IP | Updates `ext_rtp_ip` in `conf/vars_diff.xml`. |
| `--advertise-external-ip` | off | Rewrites the `drachtio_mrf` profile so it uses `$$ext_sip_ip` and `$$ext_rtp_ip`. |
| `--username` | `Jambonz-Mediaserver` | Rewrites the SIP profile username to `<value>-Mediaserver`. |
| `--log-level`, `-l` | `notice` | Rewrites `autoload_configs/switch.conf.xml`. |
| `--g711-only`, `-g` | off | Rewrites codec preferences in `conf/vars.xml`. |
| `--g711-only-alaw-preferred` | off | Rewrites codec preferences in `conf/vars.xml` with `PCMA` first. |
| `--codec-list` | branch defaults | Rewrites global and outbound codec prefs in `conf/vars.xml`. |
| `--codec-answer-generous` | off | Attempts to change inbound codec negotiation in the MRF SIP profile. |

### Important caveats about those flags

- `--advertise-external-ip` is required if you want `--ext-sip-ip` and `--ext-rtp-ip` to affect the `drachtio_mrf` profile. Without it, `files/sip_profiles/mrf.xml` advertises `$${local_ip_v4}`.
- `--g711-only`, `--g711-only-alaw-preferred`, and `--codec-list` update `vars.xml`, but the shipped `drachtio_mrf` profile in `files/sip_profiles/mrf.xml` hardcodes `codec-prefs=PCMU,PCMA,G722,OPUS`. For the main MRF profile, these flags are not a full codec override.
- `--codec-answer-generous` currently targets a `greedy` value, but the checked-in `files/sip_profiles/mrf.xml` ships with `inbound-codec-negotiation="scrooge"`. In the current branch, that flag is effectively a no-op unless the profile is changed.

## Ports, volumes, and paths

The Dockerfile does not declare any `EXPOSE` lines, so you must publish ports explicitly or use host networking.

Default ports used by the shipped configuration:

| Port | Protocol | Purpose |
| --- | --- | --- |
| `5080` | UDP/TCP | Main SIP listener for the `drachtio_mrf` profile |
| `5081` | TCP | TLS SIP listener for the `drachtio_mrf` profile |
| `8021` | TCP | FreeSWITCH event socket |
| `25000-39000` | UDP | RTP media range |
| `5036` | UDP/TCP | `internal` SIP profile in the checked-in XML |
| `5037` | UDP/TCP | `external` SIP profile in the checked-in XML |

Declared Docker volumes:

| Path | Notes |
| --- | --- |
| `/usr/local/freeswitch/log` | Persist FreeSWITCH logs here. |
| `/usr/local/freeswitch/recordings` | Persist recordings here. |
| `/usr/local/freeswitch/sounds` | Optional. Mounting an empty directory here hides the sounds installed at build time. |

Other important runtime paths:

| Path | Notes |
| --- | --- |
| `/var/pres3fs` | Created by the Dockerfile and watched by `monitorPres3fs.sh`. Not declared as a Docker volume. |
| `/var/log/monitorPres3fs.log` | Log file for the background upload watcher. |
| `/usr/local/freeswitch/conf` | Effective FreeSWITCH config tree inside the container. |

## FreeSWITCH configuration shipped by this branch

### Top-level XML

`files/freeswitch.xml`:

- includes `vars_diff.xml` before `vars.xml`
- sets `global_codec_prefs=OPUS,G722,PCMU,PCMA,VP8,H264`
- sets `outbound_codec_prefs=OPUS,G722,PCMU,PCMA,VP8,H264`
- includes `autoload_configs/*.xml`
- includes `dialplan/*.xml`

### SIP profiles

`files/sip_profiles/mrf.xml` defines the main `drachtio_mrf` profile with:

- context `mrf`
- SIP on `5080`
- TLS SIP on `5081`
- username `Jambonz-Mediaserver`
- `enable-3pcc=true`
- codec prefs `PCMU,PCMA,G722,OPUS`
- default external addresses set to `$${local_ip_v4}` unless changed at runtime

`files/sip_profiles/internal.xml` and `files/sip_profiles/external.xml` are also copied into the image and define auxiliary profiles on `5036` and `5037`.

### Dialplans

`files/dialplan/mrf.xml` is the important one for drachtio integration:

- it matches calls where `sip_user_agent` starts with `drachtio-fsmrf:`
- answers the call
- sets `send_silence_when_idle=-1`
- sets `hangup_after_bridge=false`
- sets `park_after_bridge=true`
- disables playback terminators
- connects the channel to an outbound ESL socket using the `X-esl-outbound` SIP header

The `internal` and `external` dialplans provide simple transfer and playback behavior for 4-digit test numbers.

## Modules loaded by this image

This image is not minimal.

The build stage installs `modules.conf.xml` from `deployment-tools/packer/files/modules.conf.vanilla.xml.extra`, which enables a broad jambonz-oriented module set, including:

- core call control modules such as `mod_sofia`, `mod_event_socket`, `mod_commands`, `mod_conference`, `mod_db`, `mod_dptools`, `mod_httapi`, and `mod_dialplan_xml`
- media helpers such as `mod_audio_fork`, `mod_avmd`, `mod_vad_detect`, and `mod_vad_silero`
- codec and file modules such as `mod_spandsp`, `mod_g729`, `mod_amr`, `mod_opus`, `mod_sndfile`, `mod_shout`, `mod_local_stream`, and `mod_tone_stream`
- language/runtime support including `mod_lua`
- cloud AI integrations such as `mod_aws_tts`, `mod_aws_lex`, `mod_aws_transcribe_ws`, `mod_azure_transcribe`, `mod_azure_tts`, `mod_google_transcribe`, `mod_openai_transcribe`, `mod_openai_s2s`, `mod_soniox_transcribe`, `mod_speechmatics_transcribe`, `mod_deepgram_transcribe`, `mod_deepgram_tts`, `mod_cartesia_tts`, `mod_elevenlabs_tts`, `mod_assemblyai_transcribe`, and others

If you need the exact list, inspect `deployment-tools/packer/files/modules.conf.vanilla.xml.extra`.

## Patches and custom source changes applied during build

`deployment-tools/packer/scripts/install_freeswitch.sh` applies a non-trivial set of customizations during the build:

- patches `switch_core_media.c`
- patches `switch_rtp.c`
- patches `switch_types.h`
- patches `mod_avmd.c`
- patches `mod_httapi.c`
- patches `mod_event_socket.c`
- replaces `switch_event.c`
- replaces parts of `mod_conference`
- patches `libwebsockets` `ops-ws.c`

This is another reason the old “minimal base image” description is no longer accurate for this branch.

## Startup side effects and operational behavior

At container startup, `files/entrypoint.sh` does more than launch FreeSWITCH:

- writes `AWS_KEY:AWS_SECRET_KEY` into a local `passwd` file
- starts `/usr/local/bin/monitorPres3fs.sh` in the background
- starts `rsyslogd` if present
- forces the ESL listener to `0.0.0.0`
- forces an ACL entry that allows ESL connections from `0.0.0.0/0`

`files/monitorPres3fs.sh`:

- watches `/var/pres3fs` with `inotifywait`
- uploads new files to the hardcoded bucket path `s3://vidamedia/recordings/<filename>`
- logs to `/var/log/monitorPres3fs.log`
- deletes files older than 3 days from `/var/pres3fs`

Notes:

- the `s3fs` mount command in `entrypoint.sh` is currently commented out, so the active S3-related behavior is the upload watcher, not an S3FS mount
- `entrypoint.sh` writes `AWS_KEY` and `AWS_SECRET_KEY` into a local `passwd` file for the commented-out `s3fs` flow, but the active upload watcher uses `aws s3 cp`
- for the active watcher, you still need valid AWS CLI credentials such as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, or another supported AWS credential source
- missing or invalid AWS credentials do not stop FreeSWITCH from starting, but uploads from `/var/pres3fs` will fail
- the container runs as root because the entrypoint edits config files and starts background services

## Relevant build args and environment variables

Build arguments:

- `TARGETARCH` is required and must be `amd64` or `arm64`
- `DISTRO_IMAGE` defaults to `debian:12`

Runtime environment variables actually referenced by the current scripts:

- `AWS_KEY` and `AWS_SECRET_KEY` are only used to create the `passwd` file for the commented-out `s3fs` path
- AWS CLI-compatible credentials such as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are what the active `aws s3 cp` upload path needs

## Security notes

This branch is permissive by default. Before exposing it outside a trusted network, account for the following:

- the event socket is bound to `0.0.0.0`
- the generated ACL allows `0.0.0.0/0`
- the default ESL password is `JambonzR0ck$`
- the container includes an always-on background process that attempts S3 uploads from `/var/pres3fs`

Recommended minimum hardening:

- always override `--password`
- publish `8021/tcp` only where it is needed, or keep the container on a private network
- use `--advertise-external-ip --ext-sip-ip ... --ext-rtp-ip ...` when running behind NAT
- mount only the volumes you actually need

## Useful debug commands

Container logs:

```bash
docker logs -f fs-mrf
```

FreeSWITCH CLI:

```bash
docker exec -it fs-mrf fs_cli -p 'JambonzR0ck$'
```

Watch FreeSWITCH log:

```bash
docker exec -it fs-mrf tail -f /usr/local/freeswitch/log/freeswitch.log
```

Watch the S3 upload monitor:

```bash
docker exec -it fs-mrf tail -f /var/log/monitorPres3fs.log
```

## Deployment tooling in this repository

The top-level container image is only one part of this repository.

The `deployment-tools/` directory also contains:

- packer templates for AWS, GCP, and SSH-based installation
- scripts that build full jambonz variants such as `mini`, `fs`, `sip-rtp`, `web`, and `monitoring`
- terraform for GCP mini deployments
- cloudformation for AWS mini deployments
- post-install and operational checklists

If you are trying to build a full jambonz environment rather than only this container image, start by reading:

- `deployment-tools/packer/README.md`
- `deployment-tools/SSH_Install.md`
- `deployment-tools/terraform/gcp/mini/README.md`
- `deployment-tools/Mini_Post-Install_Checks.md`

## Summary

Use this repository as:

- a source build for a custom jambonz-oriented FreeSWITCH container image
- a home for the patches and config that make that image work
- a companion repository for machine-image and infrastructure automation under `deployment-tools/`

Do not rely on older instructions that mention:

- a slim or minimal image
- no scripting languages
- no sounds
- `ClueCon` as the default ESL password
- `build-locally.sh`
- `.env` as the active source of Docker build versions
