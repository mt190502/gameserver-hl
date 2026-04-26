FROM debian:bookworm-slim

ARG GAME_VARIANT=cstrike

#~ Versions
ARG amxmodx_version=1.10
ARG metamod_version=1.3.0.149
ARG reapi_version=5.24.0.300
ARG regamedll_version=5.26.0.668
ARG rehlds_version=3.13.0.788
ARG reunion_version=0.2.0.25
ARG redeathmatch_version=1.0.0-b11

#~ URLs
ARG steamcmd_url="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
ARG amxmod_base_url="https://www.amxmodx.org/amxxdrop/${amxmodx_version}/amxmodx-latest-base-linux.tar.gz"
ARG amxmod_cstrike_url="https://www.amxmodx.org/amxxdrop/${amxmodx_version}/amxmodx-latest-cstrike-linux.tar.gz"
ARG metamod_url="https://github.com/rehlds/Metamod-R/releases/download/${metamod_version}/metamod-bin-${metamod_version}.zip"
ARG reapi_url="https://github.com/rehlds/ReAPI/releases/download/${reapi_version}/reapi-bin-${reapi_version}.zip"
ARG regamedll_url="https://github.com/rehlds/ReGameDLL_CS/releases/download/${regamedll_version}/regamedll-bin-${regamedll_version}.zip"
ARG rehlds_url="https://github.com/rehlds/ReHLDS/releases/download/${rehlds_version}/rehlds-bin-${rehlds_version}.zip"
ARG reunion_url="https://github.com/rehlds/ReUnion/releases/download/${reunion_version}/reunion-${reunion_version}.zip"
ARG redeathmatch_url="https://github.com/ReDeathmatch/ReDeathmatch_AMXX/releases/download/${redeathmatch_version}/ReDeathmatch-${redeathmatch_version}.zip"

############# LOCALES & DEPENDENCIES & ENVs ##############
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
    locales ca-certificates curl:i386 lib32gcc-s1 libstdc++6:i386 unzip xz-utils zip && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
ENV LANG en_US.utf8
ENV LC_ALL en_US.UTF-8
ENV CPU_MHZ=2300
##########################################################

########## CREATE STEAM USER & INSTALL STEAMCMD ##########
#~ Create steam user
RUN groupadd -r steam && useradd -r -g steam -m -d /opt/steam steam

USER steam
WORKDIR /opt/steam
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

#~ Copy install scripts
COPY --chown=steam:steam ./lib/*.install /opt/steam/

#~ Install steamcmd
RUN curl -sL "$steamcmd_url" | tar xzvf - \
    && mkdir -p "$HOME/.steam" \
    && ln -s "$PWD/linux32" "$HOME/.steam/sdk32"

#~ Install Game Base
RUN if [ "$GAME_VARIANT" = "cstrike" ]; then \
        ./steamcmd.sh +runscript hlds.install; \
        mkdir -p hlds/cstrike/config; \
        touch hlds/cstrike/listip.cfg hlds/cstrike/banned.cfg hlds/cstrike/config/server.cfg; \
    elif [ "$GAME_VARIANT" = "halflife" ]; then \
        ./steamcmd.sh +runscript hlds_valve.install; \
        mkdir -p hlds/valve/config; \
        touch hlds/valve/listip.cfg hlds/valve/banned.cfg hlds/valve/config/server.cfg; \
    elif [ "$GAME_VARIANT" = "svencoop" ]; then \
        ./steamcmd.sh +runscript svends.install; \
        mkdir -p svends/svencoop/config; \
        touch svends/svencoop/listip.cfg svends/svencoop/banned.cfg svends/svencoop/config/server.cfg; \
        ./steamcmd.sh +runscript opfor.install; \
        pushd svends/svencoop && bash ./Install_OpFor_Support.sh && popd; \
    fi
##########################################################

################ INSTALL REHLDS & PLUGINS ################
#~ Install Mods (ReHLDS, Metamod, AMXX, etc.) - Only for cstrike and halflife
RUN if [ "$GAME_VARIANT" = "cstrike" ] || [ "$GAME_VARIANT" = "halflife" ]; then \
        # Install ReHLDS
        curl -sL "$rehlds_url" -o "rehlds.zip" \
        && unzip "rehlds.zip" -d "rehlds" \
        && cp -R rehlds/bin/linux32/* hlds/; \
        \
        # Install Metamod-R
        curl -sL "$metamod_url" -o "metamod.zip" \
        && unzip "metamod.zip" -d "metamod" \
        && MOD_DIR=$([ "$GAME_VARIANT" = "cstrike" ] && echo "cstrike" || echo "valve") \
        && cp -R metamod/addons hlds/$MOD_DIR/ \
        && touch hlds/$MOD_DIR/addons/metamod/plugins.ini \
        && if [ "$GAME_VARIANT" = "cstrike" ]; then \
             sed -i "s/dlls\/cs\.so/addons\/metamod\/metamod_i386\.so/g" hlds/$MOD_DIR/liblist.gam; \
           elif [ "$GAME_VARIANT" = "halflife" ]; then \
             sed -i "s/dlls\/hl\.so/addons\/metamod\/metamod_i386\.so/g" hlds/$MOD_DIR/liblist.gam; \
           fi; \
        \
        # Install AMX Mod X
        curl -sL "$amxmod_base_url" | tar -C hlds/$MOD_DIR/ -zxvf -; \
        if [ "$GAME_VARIANT" = "cstrike" ]; then \
            curl -sL "$amxmod_cstrike_url" | tar -C hlds/$MOD_DIR/ -zxvf -; \
        fi; \
        echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> hlds/$MOD_DIR/addons/metamod/plugins.ini; \
        cat hlds/$MOD_DIR/mapcycle.txt >> hlds/$MOD_DIR/addons/amxmodx/configs/maps.ini || true; \
    fi

#~ Install CStrike specific (ReGameDLL, ReAPI, ReUnion, ReDeathmatch)
RUN if [ "$GAME_VARIANT" = "cstrike" ]; then \
        # ReGameDLL
        curl -sL "$regamedll_url" -o "regamedll.zip" \
        && unzip "regamedll.zip" -d "regamedll" \
        && cp -R regamedll/bin/linux32/cstrike hlds/; \
        \
        # ReAPI
        curl -sL "$reapi_url" -o "reapi.zip" \
        && unzip "reapi.zip" -d "reapi" \
        && cp -R reapi/addons/* hlds/cstrike/addons/; \
        \
        # ReUnion
        curl -sL "$reunion_url" -o "reunion.zip" \
        && unzip "reunion.zip" -d "reunion" \
        && mkdir -p hlds/cstrike/addons/reunion \
        && cp -R reunion/bin/Linux/* hlds/cstrike/addons/reunion/ \
        && cp -R reunion/reunion.cfg hlds/cstrike/ \
        && cp -R reunion/amxx/* hlds/cstrike/addons/amxmodx/scripting/ \
        && echo 'linux addons/reunion/reunion_mm_i386.so' >> hlds/cstrike/addons/metamod/plugins.ini \
        && sed -i 's/AuthVersion = 3/AuthVersion = 2/g; s/SteamIdHashSalt =/SteamIdHashSalt = 32/g' hlds/cstrike/reunion.cfg; \
        \
        # ReDeathmatch
        curl -sL "$redeathmatch_url" -o "redeathmatch.zip" \
        && unzip "redeathmatch.zip" -d "redeathmatch" \
        && cp -R redeathmatch/cstrike/addons/* hlds/cstrike/addons/; \
    fi

#~ Cleanup
RUN rm -rf *.zip *.install rehlds metamod regamedll reapi reunion redeathmatch
##########################################################

############# PERMISSIONS & WORKDIR & PORTS ##############
#~ Copy entrypoint
COPY --chown=steam:steam ./lib/entrypoint.sh /opt/steam/
RUN chmod +x /opt/steam/entrypoint.sh

#~ Copy config files
COPY --chown=steam:steam ./cstrike /opt/steam/hlds/cstrike/
COPY --chown=steam:steam ./valve /opt/steam/hlds/valve/
COPY --chown=steam:steam ./svencoop /opt/steam/svends/svencoop/

#~ Copy Custom AMX Plugins
COPY --chown=steam:steam ./lib/amxmodx /tmp/amxmodx
RUN if [ "$GAME_VARIANT" = "cstrike" ] || [ "$GAME_VARIANT" = "halflife" ]; then \
        MOD_DIR=$([ "$GAME_VARIANT" = "cstrike" ] && echo "cstrike" || echo "valve"); \
        cp -R /tmp/amxmodx/* hlds/$MOD_DIR/addons/amxmodx/; \
        if [ "$GAME_VARIANT" = "cstrike" ]; then \
            echo 'damager_reapi.amxx                 ; show damage' >> hlds/$MOD_DIR/addons/amxmodx/configs/plugins.ini \
            && echo 'next21_kill_assist.amxx             ; kill assist mode' >> hlds/$MOD_DIR/addons/amxmodx/configs/plugins.ini \
            && echo 'resetscore.amxx          ; reset user score' >> hlds/$MOD_DIR/addons/amxmodx/configs/plugins.ini; \
        fi; \
    fi; \
    rm -rf /tmp/amxmodx

#~ Set Environment Variables
RUN if [ "$GAME_VARIANT" = "svencoop" ]; then \
        echo "export SERVER_ROOT=/opt/steam/svends" > /opt/steam/.env; \
        echo "export GAME_MOD=svencoop" >> /opt/steam/.env; \
        echo "export BINARY_NAME=svends_run" >> /opt/steam/.env; \
        echo "276060" > steam_appid.txt; \
    elif [ "$GAME_VARIANT" = "halflife" ]; then \
        echo "export SERVER_ROOT=/opt/steam/hlds" > /opt/steam/.env; \
        echo "export GAME_MOD=valve" >> /opt/steam/.env; \
        echo "export BINARY_NAME=hlds_run" >> /opt/steam/.env; \
        echo "90" > steam_appid.txt; \
    else \
        echo "export SERVER_ROOT=/opt/steam/hlds" > /opt/steam/.env; \
        echo "export GAME_MOD=cstrike" >> /opt/steam/.env; \
        echo "export BINARY_NAME=hlds_run" >> /opt/steam/.env; \
        echo "90" > steam_appid.txt; \
    fi

WORKDIR /opt/steam
USER root
RUN chown -R steam:steam /opt/steam
USER steam

#~ Expose ports
EXPOSE 27015 27015/udp

#~ Entrypoint
ENTRYPOINT ["./entrypoint.sh"]
##########################################################
