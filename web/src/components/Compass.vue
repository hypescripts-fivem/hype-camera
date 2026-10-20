<script setup lang="ts">
import { computed } from 'vue';
import { useCameraStore } from '../store';
import { pad } from '../utils';

const props = defineProps<{ heading: number }>();
const store = useCameraStore();

const VISIBLE = 100; // visible degree range
const directions = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'];

const ticks = computed(() => {
    const start = Math.ceil((props.heading - VISIBLE / 2) / 5) * 5;
    const list = [];

    for (let deg = start; deg <= props.heading + VISIBLE / 2; deg += 5) {
        const value = ((deg % 360) + 360) % 360;
        const position = 50 + ((deg - props.heading) / VISIBLE) * 100;
        const cardinal = value % 45 === 0 ? store.locale(`ui.compass.${directions[value / 45]}`) : null;
        list.push({ deg, value, position, cardinal, major: value % 15 === 0 });
    }
    return list;
});
</script>

<template>
    <div class="flex flex-col items-center">
        <div
            class="relative h-[2.4rem] w-[34rem] overflow-hidden"
            style="mask-image: linear-gradient(to right, transparent, black 18%, black 82%, transparent)"
        >
            <div
                v-for="tick in ticks" :key="tick.deg"
                class="absolute bottom-0 flex -translate-x-1/2 flex-col items-center"
                :style="{ left: `${tick.position}%` }"
            >
                <span v-if="tick.cardinal" class="mb-0.5 text-[0.78rem] font-bold text-phosphor glow">{{ tick.cardinal }}</span>
                <span v-else-if="tick.major" class="mb-0.5 text-[0.56rem] text-phosphor/55">{{ tick.value }}</span>
                <span class="w-px bg-phosphor/80" :class="tick.cardinal ? 'h-2.5' : tick.major ? 'h-2' : 'h-1 opacity-60'" />
            </div>
        </div>

        <svg viewBox="0 0 12 7" class="mt-0.5 h-[0.45rem] w-[0.8rem] text-scan" fill="currentColor"><path d="M6 0l6 7H0z" /></svg>
        <div class="text-[0.72rem] font-semibold tracking-[0.18em] text-phosphor glow-soft">
            {{ store.locale('ui.heading') }} {{ pad(Math.round(heading) % 360, 3) }}°
        </div>
    </div>
</template>
