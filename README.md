# LLM Server (Omarchy bar widget)

A bar widget for the local llama.cpp server. Shows whether the server is up and
gives one-click **start / stop / restart** from the Omarchy bar.

- Plugin id: `rene.llm-server` · kind: `bar-widget` · author: rene · license: MIT
- Category: System, right section, single instance.

## What it drives

The widget shells out to `~/Projects/vox-workspace/local-llm/llm.sh`:

```bash
/bin/bash ~/Projects/vox-workspace/local-llm/llm.sh start|stop|restart
```

Status is read from the same server (see `Panel.qml`). If the script is missing
or not executable, the widget reports the failure inline.

## Install

This repo is the source of truth; the plugin dir
(`~/.config/omarchy/plugins/rene.llm-server`) is a deployed copy. Never edit the
deployed copy by hand.

```bash
./install.sh --enable      # validate, copy into the plugin dir, rescan, enable
```

Flags: `--enable` (also enable the plugin), `--no-lint` (skip the optional lint
script if one exists), `-h` for usage.

## Layout

```
plugin/manifest.json   plugin metadata (id, kind, entry point)
plugin/Panel.qml       the bar widget
install.sh             repo -> live plugin dir
```

## Notes

- No engine or service of its own: the LLM server itself is managed by
  `llm.sh`; this widget is only the bar control surface.
- `install.sh` copies `manifest.json` + every `*.qml` (and `lib/` if present)
  into the plugin dir, then runs `omarchy-shell shell rescanPlugins`.
