<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useCameraStore } from '../store';
import { countdown, pad } from '../utils';
import AppIcon from './AppIcon.vue';

const store = useCameraStore();

const now = ref(new Date());
let timer: ReturnType<typeof setInterval> | undefined;
onMounted(() => (timer = setInterval(() => (now.value = new Date()), 1000)));
onBeforeUnmount(() => clearInterval(timer));

const time = computed(() => `${pad(now.value.getHours())}:${pad(now.value.getMinutes())}:${pad(now.value.getSeconds())}`);

const categories = computed(() => [
    { id: 'all', label: store.locale('ui.all'), icon: 'grid' },
    ...store.categories.map((category) => ({ ...category, icon: category.icon ?? 'camera' })),
]);
</script>

<template>
    <div class="fixed inset-0 flex items-center justify-center bg-black/55">
        <div class="clip-panel flex h-[min(84vh,52rem)] w-[min(88vw,86rem)] flex-col border border-line bg-console/95 shadow-[0_2rem_5rem_rgba(0,0,0,0.6)]">
            <!-- Top bar -->
            <header class="flex items-center gap-5 border-b border-line px-6 py-4">
                <div class="flex items-center gap-3">
                    <div class="flex h-11 w-11 items-center justify-center border border-rec/40 bg-rec/10 text-rec">
                        <AppIcon name="camera" class="h-6 w-6" />
                    </div>
                    <div>
                        <div class="font-display text-[1.5rem] font-bold uppercase leading-none tracking-[0.12em] text-phosphor">{{ store.ui.brand }}</div>
                        <div class="mt-1 text-[0.68rem] tracking-[0.22em] text-phosphor/50">{{ store.locale('ui.subtitle').toLocaleUpperCase(store.ui.locale) }}</div>
                    </div>
                </div>

                <label class="ml-auto flex h-10 w-[22rem] items-center gap-2.5 border border-line bg-black/40 px-3 text-phosphor/50 focus-within:border-phosphor/40">
                    <AppIcon name="search" class="h-4 w-4 shrink-0" />
                    <input
                        v-model="store.search"
                        :placeholder="store.locale('ui.search')"
                        class="w-full bg-transparent text-[0.85rem] text-phosphor placeholder:text-phosphor/35 outline-none select-text"
                    />
                </label>

                <div class="text-right">
                    <div class="text-[1.25rem] font-bold leading-none tabular-nums text-phosphor">{{ time }}</div>
                    <div class="mt-1 flex items-center justify-end gap-1.5 text-[0.62rem] tracking-[0.15em] text-ok/80">
                        <span class="h-1.5 w-1.5 rounded-full bg-ok" />
                        {{ store.locale('ui.online_count', store.onlineCount, store.cameras.length) }}
                    </div>
                </div>

                <button
                    class="flex h-10 w-10 cursor-pointer items-center justify-center border border-line text-phosphor/60 transition hover:border-alert/60 hover:bg-alert/10 hover:text-alert"
                    :title="store.locale('ui.close')"
                    @click="store.CloseUI()"
                >
                    <AppIcon name="close" class="h-5 w-5" />
                </button>
            </header>

            <div class="flex min-h-0 flex-1">
                <!-- Categories -->
                <nav class="w-[16rem] shrink-0 space-y-1 border-r border-line p-3">
                    <button
                        v-for="category in categories" :key="category.id"
                        class="flex w-full cursor-pointer items-center gap-3 border-l-2 px-3 py-2.5 text-left text-[0.82rem] transition"
                        :class="store.category === category.id
                            ? 'border-rec bg-phosphor/[0.07] text-phosphor'
                            : 'border-transparent text-phosphor/55 hover:bg-phosphor/[0.04] hover:text-phosphor/85'"
                        @click="store.category = category.id"
                    >
                        <AppIcon :name="category.icon" class="h-[1.1rem] w-[1.1rem] shrink-0" />
                        <span class="flex-1 truncate font-semibold">{{ category.label }}</span>
                        <span class="text-[0.7rem] tabular-nums text-phosphor/40">{{ store.countOf(category.id) }}</span>
                    </button>
                </nav>

                <!-- Camera grid -->
                <main class="min-h-0 flex-1 overflow-y-auto p-4">
                    <div v-if="store.filtered.length" class="grid grid-cols-4 gap-3">
                        <button
                            v-for="camera in store.filtered" :key="camera.id"
                            class="clip-card group relative overflow-hidden border text-left transition"
                            :class="camera.online
                                ? 'cursor-pointer border-line bg-console-2 hover:border-phosphor/45'
                                : 'cursor-not-allowed border-line/50 bg-console-2/60 opacity-55'"
                            :disabled="!camera.online || store.busy"
                            @click="store.Connect(camera)"
                        >
                            <!-- Monitor preview -->
                            <div class="relative aspect-video overflow-hidden">
                                <div class="static-bg absolute inset-0" :class="camera.online ? 'opacity-25 group-hover:opacity-40' : 'opacity-70'" />
                                <div class="scanlines absolute inset-0" />
                                <div class="vignette absolute inset-0" />

                                <div class="absolute left-2 top-1.5 flex items-center gap-1.5 text-[0.62rem] font-bold tracking-[0.12em] text-phosphor/85">
                                    <span v-if="camera.online" class="blink h-1.5 w-1.5 rounded-full bg-rec" />
                                    {{ camera.code }}
                                </div>
                                <div
                                    class="absolute right-2 top-1.5 text-[0.56rem] font-bold tracking-[0.15em]"
                                    :class="camera.online ? 'text-ok/80' : 'text-alert'"
                                >
                                    {{ camera.online ? store.locale('ui.online') : store.locale('ui.offline') }}
                                </div>

                                <div v-if="!camera.online" class="absolute inset-0 flex flex-col items-center justify-center gap-1">
                                    <span class="bg-black/80 px-2 py-0.5 font-display text-[1rem] font-bold tracking-[0.2em] text-alert">
                                        {{ camera.offlineUntil ? store.locale('ui.destroyed') : store.locale('ui.no_signal') }}
                                    </span>
                                    <span v-if="camera.offlineUntil" class="bg-black/70 px-1.5 text-[0.8rem] font-bold tabular-nums tracking-[0.1em] text-phosphor">
                                        {{ countdown(camera.offlineUntil - now.getTime()) }}
                                    </span>
                                </div>
                                <div v-else class="absolute inset-0 flex items-center justify-center opacity-0 transition group-hover:opacity-100">
                                    <span class="border border-phosphor/50 bg-black/70 px-3 py-1 text-[0.7rem] font-bold tracking-[0.25em] text-phosphor">
                                        {{ store.locale('ui.connect') }} ▸
                                    </span>
                                </div>
                            </div>

                            <div class="border-t border-line px-2.5 py-2">
                                <div class="truncate text-[0.8rem] font-semibold text-phosphor">{{ camera.label }}</div>
                                <div class="mt-0.5 truncate text-[0.62rem] tracking-[0.12em] text-phosphor/45">{{ camera.categoryLabel.toLocaleUpperCase(store.ui.locale) }}</div>
                            </div>
                        </button>
                    </div>

                    <div v-else class="flex h-full flex-col items-center justify-center gap-3 text-phosphor/40">
                        <AppIcon name="search" class="h-10 w-10" />
                        <span class="text-[0.85rem] tracking-[0.1em]">{{ store.locale('ui.no_results') }}</span>
                    </div>
                </main>
            </div>

            <!-- Bottom bar -->
            <footer class="flex items-center justify-between border-t border-line px-6 py-2.5 text-[0.66rem] tracking-[0.12em] text-phosphor/45">
                <span>{{ store.locale('ui.channel', pad(store.filtered.length), pad(store.cameras.length)) }}</span>
                <Transition name="fade">
                    <span v-if="store.error" class="font-bold text-alert">{{ store.locale(`ui.error.${store.error}`) }}</span>
                </Transition>
                <span class="flex items-center gap-1.5">
                    <kbd class="border border-phosphor/30 px-1 font-bold text-phosphor/70">ESC</kbd>
                    {{ store.locale('ui.close') }}
                </span>
            </footer>
        </div>
    </div>
</template>
