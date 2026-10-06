#!/usr/bin/env bash
# =============================================================================
#  Envoltorio de 'ign' (instalado como /usr/local/bin/ign, delante de /usr/bin)
#
#  En WSL la GPU llega vía D3D12 con OpenGL 4.2 y el motor ogre2 de Gazebo
#  Fortress necesita 4.3+. Si ROBCOOP_RENDER_ENGINE está definida (p. ej. "ogre")
#  y no se ha indicado ya un motor, se añade '--render-engine <motor>' a
#  'ign gazebo ...'. Funciona también desde los launch (ros_gz_sim, ExecuteProcess).
# =============================================================================
REAL=/usr/bin/ign
if [ "$1" = "gazebo" ] && [ -n "$ROBCOOP_RENDER_ENGINE" ]; then
    case " $* " in
        *" --render-engine"*) ;;                       # ya indicado: no tocar
        *) shift; exec "$REAL" gazebo --render-engine "$ROBCOOP_RENDER_ENGINE" "$@" ;;
    esac
fi
exec "$REAL" "$@"
