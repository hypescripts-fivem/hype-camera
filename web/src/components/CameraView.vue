<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useCameraStore } from '../store';
import { countdown, pad, signed } from '../utils';
import Compass from './Compass.vue';
import Crosshair from './Crosshair.vue';
import NoiseCanvas from './NoiseCanvas.vue';
import TargetPanel from './TargetPanel.vue';

const store = useCameraStore();

const now = ref(new Date());
let clockTimer: ReturnType<typeof setInterval> | undefined;
onMounted(() => (clockTimer = setInterval(() => (now.value = new Date()), 250)));
onBeforeUnmount(() => clearInterval(clockTimer));

const clock = computed(() => {
    const game = store.ui.clock === 'game' ? store.hud.clock : undefined;
    const date = game ? new Date(game[0], game[1] - 1, game[2], game[3], game[4], game[5]) : now.value;

    return {
        date: `${pad(date.getDate())}.${pad(date.getMonth() + 1)}.${date.getFullYear()}`,
        day: date.toLocaleDateString(store.ui.locale, { weekday: 'short' }).toLocaleUpperCase(store.ui.locale),
        time: `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`,
    };
});

const overlay = computed(() => store.connecting || store.signalLost);

const controls = computed(() => [
    { keys: ['W', 'A', 'S', 'D'], label: store.locale('ui.controls.move') },
    { keys: ['SCROLL'], label: store.locale('ui.controls.zoom') },
    { keys: ['Q', 'E'], label: store.locale('ui.controls.switch') },
    { keys: ['SHIFT'], label: store.locale('ui.controls.fast') },
    { keys: ['⌫'], label: store.locale('ui.controls.back') },
    { keys: ['ESC'], label: store.locale('ui.controls.exit') },
]);

const zoomTicks = Array.from({ length: 11 }, (_, i) => i);
</script>

<template>
    <div class="pointer-events-none fixed inset-0 overflow-hidden">
        <!-- Picture layers -->
        <div class="flicker absolute inset-0">
            <div class="absolute inset-0 opacity-[0.07] mix-blend-screen"><NoiseCanvas :width="480" :height="270" /></div>
            <div class="scanlines absolute inset-0" />
            <div class="rollbar absolute inset-x-0 top-0 h-[22vh]" />
            <div class="vignette absolute inset-0" />
        </div>
        <div class="osd-shade absolute inset-0" />

        <!-- Frame corners -->
        <div class="absolute inset-[2.2rem]">
            <span class="absolute left-0 top-0 h-6 w-6 border-l-2 border-t-2 border-phosphor/70" />
            <span class="absolute right-0 top-0 h-6 w-6 border-r-2 border-t-2 border-phosphor/70" />
            <span class="absolute bottom-0 left-0 h-6 w-6 border-b-2 border-l-2 border-phosphor/70" />
            <span class="absolute bottom-0 right-0 h-6 w-6 border-b-2 border-r-2 border-phosphor/70" />
        </div>

        <!-- Top left: recording + camera -->
        <div class="absolute left-[3.6rem] top-[3.3rem] glow-soft">
            <div class="flex items-center gap-2 text-[1rem] font-bold tracking-[0.2em]">
                <span class="blink flex items-center gap-2 text-rec">
                    <span class="h-[0.7rem] w-[0.7rem] rounded-full bg-rec shadow-[0_0_0.6rem_var(--color-rec)]" />
                    {{ store.locale('ui.rec') }}
                </span>
                <span class="text-phosphor/40">|</span>
                <span class="text-phosphor glow">{{ store.camera?.code }}</span>
            </div>
            <div class="mt-1 max-w-[30rem] truncate font-display text-[1.7rem] font-bold leading-none tracking-[0.04em] text-phosphor glow">
                {{ store.camera?.label }}
            </div>
            <div class="mt-1 text-[0.7rem] tracking-[0.25em] text-phosphor/60">{{ store.camera?.categoryLabel?.toLocaleUpperCase(store.ui.locale) }}</div>
        </div>

        <!-- Top center: brand -->
        <div class="absolute left-1/2 top-[3.3rem] -translate-x-1/2 text-center glow-soft">
            <div class="text-[0.82rem] font-bold tracking-[0.45em] text-phosphor/85">{{ store.ui.brand }}</div>
            <div class="mt-0.5 text-[0.62rem] tracking-[0.3em] text-phosphor/45">
                {{ store.locale('ui.channel', pad(store.camera?.index ?? 0), pad(store.camera?.total ?? 0)) }}
            </div>
        </div>

        <!-- Top right: date/time -->
        <div class="absolute right-[3.6rem] top-[3.3rem] text-right glow-soft">
            <div class="text-[0.78rem] tracking-[0.2em] text-phosphor/70">{{ clock.day }} {{ clock.date }}</div>
            <div class="text-[1.9rem] font-bold leading-tight tracking-[0.06em] text-phosphor glow tabular-nums">{{ clock.time }}</div>
            <div class="mt-0.5 flex items-center justify-end gap-2 text-[0.62rem] tracking-[0.2em] text-phosphor/50">
                <span class="flex items-center gap-1 text-ok/80"><span class="h-1.5 w-1.5 rounded-full bg-ok" />{{ store.locale('ui.live') }}</span>
                <span>1080P · 25FPS · H.265</span>
            </div>
        </div>

        <!-- Right: zoom bar -->
        <div class="absolute right-[3.6rem] top-1/2 flex -translate-y-1/2 items-center gap-2 glow-soft">
            <div class="text-right">
                <div class="text-[0.6rem] tracking-[0.2em] text-phosphor/50">{{ store.locale('ui.zoom') }}</div>
                <div class="text-[1.1rem] font-bold text-phosphor glow tabular-nums">x{{ store.hud.zoom.toFixed(1) }}</div>
            </div>
            <div class="relative flex h-[16rem] w-3 flex-col justify-between">
                <span v-for="tick in zoomTicks" :key="tick" class="h-px bg-phosphor/50" :class="tick % 5 === 0 ? 'w-3' : 'ml-auto w-1.5'" />
                <span
                    class="absolute -left-2 h-0 w-0 -translate-y-1/2 border-y-[0.35rem] border-l-[0.5rem] border-y-transparent border-l-scan transition-[bottom] duration-100"
                    :style="{ bottom: `${Math.max(0, Math.min(1, store.hud.zoomLevel)) * 100}%` }"
                />
            </div>
        </div>

        <!-- Left: detection log -->
        <div v-if="store.logs.length" class="absolute left-[3.6rem] top-1/2 w-[17rem] -translate-y-1/2 glow-soft">
            <div class="mb-1.5 text-[0.66rem] font-bold tracking-[0.25em] text-phosphor/60">{{ store.locale('ui.log.title') }}</div>
            <TransitionGroup name="log" tag="div" class="space-y-1">
                <div
                    v-for="log in store.logs" :key="log.key"
                    class="flex items-center gap-2 border-l-2 bg-black/35 px-2 py-1 text-[0.68rem]"
                    :class="log.status === 'identified' ? 'border-ok' : 'border-alert'"
                >
                    <span class="text-phosphor/50 tabular-nums">{{ log.time }}</span>
                    <span class="flex-1 truncate font-semibold" :class="log.status === 'identified' ? 'text-phosphor' : 'text-alert'">{{ log.name }}</span>
                    <span class="text-phosphor/40">{{ log.camera }}</span>
                </div>
            </TransitionGroup>
        </div>

        <!-- Center: crosshair + target -->
        <div class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
            <Crosshair :status="overlay ? null : (store.target?.status ?? null)" />
        </div>
        <div class="absolute left-[calc(50%+7.5rem)] top-1/2 -translate-y-1/2">
            <Transition name="panel">
                <TargetPanel v-if="store.target && !overlay" :key="store.target.id" :target="store.target" />
            </Transition>
        </div>

        <!-- Bottom left: PTZ values -->
        <div class="absolute bottom-[3.3rem] left-[3.6rem] grid grid-cols-[auto_auto_auto_auto] items-baseline gap-x-2.5 gap-y-0.5 text-[0.78rem] tabular-nums glow-soft">
            <span class="text-phosphor/60">{{ store.locale('ui.pan') }}</span><span class="mr-4 font-semibold">{{ signed(store.hud.pan) }}°</span>
            <span class="text-phosphor/60">{{ store.locale('ui.tilt') }}</span><span class="font-semibold">{{ signed(store.hud.tilt, 2) }}°</span>
            <span class="text-phosphor/60">{{ store.locale('ui.zoom') }}</span><span class="mr-4 font-semibold">x{{ store.hud.zoom.toFixed(1) }}</span>
            <span class="text-phosphor/60">{{ store.locale('ui.fov') }}</span><span class="font-semibold">{{ store.hud.fov.toFixed(1) }}°</span>
        </div>

        <!-- Bottom center: compass -->
        <div class="absolute bottom-[3rem] left-1/2 -translate-x-1/2">
            <Compass :heading="store.hud.heading" />
        </div>

        <!-- Bottom right: controls -->
        <div class="absolute bottom-[3.3rem] right-[3.6rem] flex max-w-[30rem] flex-wrap justify-end gap-x-3 gap-y-1.5 text-[0.66rem] glow-soft">
            <div v-for="control in controls" :key="control.label" class="flex items-center gap-1">
                <kbd
                    v-for="key in control.keys" :key="key"
                    class="min-w-[1.35rem] border border-phosphor/40 bg-black/40 px-1 py-px text-center font-mono text-[0.62rem] font-bold text-phosphor"
                >{{ key }}</kbd>
                <span class="ml-0.5 tracking-[0.08em] text-phosphor/65">{{ control.label }}</span>
            </div>
        </div>

        <!-- Connecting / no signal -->
        <Transition name="fade">
            <div v-if="overlay" class="absolute inset-0">
                <div class="absolute inset-0 bg-[#111]"><NoiseCanvas :fps="30" /></div>
                <div class="scanlines absolute inset-0" />
                <div class="vignette absolute inset-0" />
                <div class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 text-center">
                    <div class="inline-block bg-black/80 px-6 py-3">
                        <div
                            class="font-display text-[2.4rem] font-bold leading-none tracking-[0.2em] glow"
                            :class="store.signalLost ? 'text-alert' : 'text-phosphor'"
                        >
                            {{ store.signalLost ? store.locale('ui.signal_lost') : store.locale('ui.connecting') }}<span v-if="!store.signalLost" class="blink">_</span>
                        </div>
                        <div class="mt-1.5 text-[0.75rem] tracking-[0.2em] text-phosphor/60">
                            {{ store.camera?.code }} ·
                            <template v-if="!store.signalLost">{{ store.locale('ui.connecting_sub') }}</template>
                            <template v-else-if="store.signalUntil">{{ store.locale('ui.destroyed_sub', countdown(store.signalUntil - now.getTime())) }}</template>
                            <template v-else>{{ store.locale('ui.signal_lost_sub') }}</template>
                        </div>
                    </div>
                </div>
            </div>
        </Transition>
    </div>
</template>
