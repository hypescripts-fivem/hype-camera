<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{ name: string }>();

const icons: Record<string, string[]> = {
    camera: [
        'M16.75 12h3.63a1 1 0 0 1 .9 1.45l-2.04 4.07a1 1 0 0 1-1.7.13l-2.13-2.97',
        'M17.1 9.05a1 1 0 0 1 .45 1.34l-3.1 6.21a1 1 0 0 1-1.35.45L3.6 12.3a2.92 2.92 0 0 1-1.3-3.91L3.7 5.6a2.92 2.92 0 0 1 3.9-1.3z',
        'M2 19h3.76a2 2 0 0 0 1.8-1.1L9 15',
        'M2 21v-4',
        'M7 9h.01',
    ],
    bank: ['M3 22h18', 'M6 18v-7', 'M10 18v-7', 'M14 18v-7', 'M18 18v-7', 'M12 2l8 5H4z'],
    store: ['M3 9l1.5-5h15L21 9', 'M3 9h18', 'M5 9v11h14V9', 'M10 20v-5h4v5'],
    fuel: ['M3 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18', 'M2 22h14', 'M6 6h6v4H6z', 'M15 9h2a2 2 0 0 1 2 2v6a1.5 1.5 0 0 0 3 0V8l-3-3'],
    bottle: ['M10 2h4', 'M10 2v5l-2 3v11a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V10l-2-3V2', 'M8 14h8'],
    gem: ['M6 3h12l4 6-10 12L2 9z', 'M2 9h20', 'M10 3 8 9l4 12 4-12-2-6'],
    grid: ['M3 3h7v7H3z', 'M14 3h7v7h-7z', 'M14 14h7v7h-7z', 'M3 14h7v7H3z'],
    search: ['M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16z', 'M21 21l-4.3-4.3'],
    close: ['M18 6 6 18', 'M6 6l12 12'],
    signal: ['M2 20h.01', 'M7 20v-4', 'M12 20v-8', 'M17 20V8', 'M22 4v16'],
    user: ['M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10z', 'M3 22a9 9 0 0 1 18 0'],
};

const paths = computed(() => icons[props.name] ?? icons.camera);
</script>

<template>
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path v-for="(d, i) in paths" :key="i" :d="d" />
    </svg>
</template>
