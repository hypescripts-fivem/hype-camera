<script setup lang="ts">
import { onMounted } from 'vue';
import CameraMenu from './components/CameraMenu.vue';
import CameraView from './components/CameraView.vue';
import { useCameraStore } from './store';
import { isNative } from './utils';
import { keydownEvent, messageEvent } from './utils/events';

const store = useCameraStore();

onMounted(() => {
    messageEvent();
    keydownEvent();
});
</script>

<template>
    <div v-if="!isNative" class="preview-bg fixed inset-0" />
    <Transition name="menu">
        <CameraMenu v-if="store.mode === 'menu'" />
    </Transition>
    <CameraView v-if="store.mode === 'view'" />
</template>
