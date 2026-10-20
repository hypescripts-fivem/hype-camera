<script setup lang="ts">
import { computed } from 'vue';
import { useCameraStore, type Identity, type Target } from '../store';
import { matchRate } from '../utils';
import AppIcon from './AppIcon.vue';

const props = defineProps<{ target: Target }>();
const store = useCameraStore();

const tone = computed(() => {
    switch (props.target.status) {
        case 'identified': return { text: 'text-ok', border: 'border-ok/60', bg: 'bg-ok', soft: 'bg-ok/10' };
        case 'masked':
        case 'obscured': return { text: 'text-alert', border: 'border-alert/60', bg: 'bg-alert', soft: 'bg-alert/10' };
        default: return { text: 'text-scan', border: 'border-scan/50', bg: 'bg-scan', soft: 'bg-scan/10' };
    }
});

const formatDate = (value?: string): string => {
    if (!value) return '—';
    const parts = /^(\d{4})-(\d{1,2})-(\d{1,2})/.exec(value);
    if (!parts) return value;
    const date = new Date(Number(parts[1]), Number(parts[2]) - 1, Number(parts[3]));
    return date.toLocaleDateString(store.ui.locale, { day: '2-digit', month: '2-digit', year: 'numeric' });
};

const formatters: Record<keyof Identity, (data: Identity) => string> = {
    name: (d) => d.name || '—',
    birthdate: (d) => formatDate(d.birthdate),
    gender: (d) => d.gender === 1 ? store.locale('ui.face.female') : store.locale('ui.face.male'),
    nationality: (d) => d.nationality || '—',
    citizenid: (d) => d.citizenid || '—',
    job: (d) => d.job || '—',
    phone: (d) => d.phone || '—',
};

/** Every field except the name, in the order the server sends them */
const fields = computed(() => {
    const data = props.target.data;
    if (!data) return [];
    return (Object.keys(data) as (keyof Identity)[])
        .filter((key) => key !== 'name' && formatters[key])
        .map((key) => ({ key, label: store.locale(`ui.face.${key}`), value: formatters[key](data) }));
});

const title = computed(() => store.locale(`ui.face.${props.target.status}`));
const subtitle = computed(() => store.locale(`ui.face.${props.target.status}_sub`));
</script>

<template>
    <div
        class="clip-panel w-[23rem] border bg-black/55 backdrop-blur-[2px] glow-soft"
        :class="tone.border"
    >
        <!-- Header -->
        <div class="flex items-center justify-between border-b border-line px-3.5 py-2" :class="tone.soft">
            <div class="flex items-center gap-2 text-[0.72rem] font-bold tracking-[0.2em]" :class="tone.text">
                <span class="h-1.5 w-1.5 rounded-full" :class="[tone.bg, target.status === 'identified' ? '' : 'blink']" />
                {{ store.locale('ui.face.title') }}
            </div>
            <div class="text-[0.66rem] tracking-[0.15em] text-phosphor/60">
                {{ store.locale('ui.face.subject') }} #{{ String(target.id).padStart(4, '0') }}
            </div>
        </div>

        <!-- Scanning / query -->
        <div v-if="target.status === 'scanning' || target.status === 'matching'" class="px-3.5 py-3">
            <div class="text-[1.05rem] font-bold tracking-[0.12em] text-scan">{{ title }}</div>
            <div class="mt-0.5 text-[0.72rem] text-phosphor/60">{{ subtitle }}</div>

            <div class="relative mt-3 h-1.5 overflow-hidden bg-phosphor/10">
                <div
                    v-if="target.status === 'scanning'"
                    :key="target.scanKey"
                    class="scan-progress h-full bg-scan"
                    :style="{ animationDuration: `${target.scanTime}ms` }"
                />
                <div v-else class="indeterminate h-full w-2/5 bg-scan" />
            </div>

            <div class="mt-3 grid grid-cols-6 gap-1">
                <span
                    v-for="n in 18" :key="n"
                    class="h-1 bg-scan/60 blink"
                    :style="{ animationDelay: `${(n * 137) % 1100}ms`, animationDuration: `${700 + (n * 53) % 600}ms` }"
                />
            </div>
        </div>

        <!-- Far / masked / no face -->
        <div v-else-if="target.status !== 'identified'" class="flex items-center gap-3 px-3.5 py-3">
            <div class="flex h-14 w-12 shrink-0 items-center justify-center border" :class="[tone.border, tone.text, tone.soft]">
                <AppIcon :name="target.status === 'far' ? 'search' : 'user'" class="h-7 w-7" />
            </div>
            <div class="min-w-0">
                <div class="text-[1.05rem] font-bold tracking-[0.12em]" :class="tone.text">{{ title }}</div>
                <div class="mt-0.5 text-[0.72rem] text-phosphor/65">{{ subtitle }}</div>
            </div>
        </div>

        <!-- Identified -->
        <div v-else class="flex gap-3 px-3.5 py-3">
            <div class="relative h-[7.6rem] w-[6.2rem] shrink-0 overflow-hidden border border-ok/50 bg-black/60">
                <img v-if="target.photo" :src="target.photo" class="h-full w-full object-cover grayscale-[35%] contrast-125" />
                <AppIcon v-else name="user" class="absolute inset-0 m-auto h-12 w-12 text-ok/40" />
                <div class="scanlines absolute inset-0 opacity-70" />
                <div class="scan-sweep absolute inset-x-0 h-px bg-ok/80 shadow-[0_0_0.4rem_var(--color-ok)]" />
                <div class="absolute inset-x-0 bottom-0 bg-black/70 py-0.5 text-center text-[0.6rem] font-bold tracking-[0.15em] text-ok">
                    {{ matchRate(target.id) }}%
                </div>
            </div>

            <div class="min-w-0 flex-1">
                <div class="text-[0.62rem] font-bold tracking-[0.2em] text-ok">{{ title }}</div>
                <div class="truncate font-display text-[1.5rem] font-bold leading-tight text-phosphor glow">
                    {{ target.data?.name || '—' }}
                </div>

                <div class="mt-1.5 space-y-[0.2rem]">
                    <div v-for="field in fields" :key="field.key" class="flex items-baseline justify-between gap-2 text-[0.7rem]">
                        <span class="shrink-0 tracking-[0.1em] text-phosphor/50">{{ field.label }}</span>
                        <span class="truncate text-right font-semibold text-phosphor">{{ field.value }}</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Footer -->
        <div class="flex items-center justify-between border-t border-line px-3.5 py-1.5 text-[0.64rem] tracking-[0.12em] text-phosphor/55">
            <span>{{ store.locale('ui.face.distance') }} {{ target.distance.toFixed(1) }} m</span>
            <span v-if="target.status === 'identified'" class="text-ok/80">{{ store.locale('ui.face.match') }} {{ matchRate(target.id) }}%</span>
            <span v-else>{{ store.camera?.code }}</span>
        </div>
    </div>
</template>
