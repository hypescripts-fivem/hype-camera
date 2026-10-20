<script setup lang="ts">
import { computed } from 'vue';
import type { TargetStatus } from '../store';

const props = defineProps<{ status: TargetStatus | null }>();

const color = computed(() => {
    switch (props.status) {
        case 'identified': return 'var(--color-ok)';
        case 'masked':
        case 'obscured': return 'var(--color-alert)';
        case 'scanning':
        case 'matching':
        case 'far': return 'var(--color-scan)';
        default: return 'rgba(231, 242, 228, 0.85)';
    }
});

const locked = computed(() => props.status !== null);
const busy = computed(() => props.status === 'scanning' || props.status === 'matching');
</script>

<template>
    <svg
        viewBox="0 0 200 200"
        class="h-[13rem] w-[13rem] drop-shadow-[0_0_0.2rem_rgba(0,0,0,0.9)] transition-colors duration-300"
        :style="{ color }"
        fill="none"
        stroke="currentColor"
    >
        <!-- Outer corners: pulled in when a target is locked -->
        <g
            class="transition-transform duration-300 ease-out"
            :style="{ transform: locked ? 'scale(0.72)' : 'scale(1)', transformOrigin: '100px 100px' }"
            stroke-width="2.2"
        >
            <path d="M28 54V28h26" />
            <path d="M146 28h26v26" />
            <path d="M172 146v26h-26" />
            <path d="M54 172H28v-26" />
        </g>

        <!-- Scan ring -->
        <circle
            v-if="locked"
            cx="100" cy="100" r="46"
            stroke-width="1.2"
            stroke-dasharray="4 7"
            :class="busy ? 'spin-slow' : ''"
            opacity="0.7"
        />
        <circle v-else cx="100" cy="100" r="46" stroke-width="1" stroke-dasharray="1 9" opacity="0.35" />

        <!-- Cross -->
        <g stroke-width="1.6">
            <path d="M100 66v24" />
            <path d="M100 110v24" />
            <path d="M66 100h24" />
            <path d="M110 100h24" />
        </g>
        <circle cx="100" cy="100" r="1.6" fill="currentColor" stroke="none" />

        <!-- Edge ticks -->
        <g stroke-width="1" opacity="0.55">
            <path d="M100 10v8" />
            <path d="M100 182v8" />
            <path d="M10 100h8" />
            <path d="M182 100h8" />
        </g>
    </svg>
</template>
