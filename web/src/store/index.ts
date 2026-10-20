import { defineStore } from 'pinia';
import { FetchNUI, isNative } from '../utils';
import previewLocale from '../../../locales/tr.json';

export type Mode = 'hidden' | 'menu' | 'view';

export interface UIConfig {
    brand: string;
    locale: string;
    clock: 'real' | 'game';
}

export interface Category {
    id: string;
    label: string;
    icon?: string;
}

export interface CameraItem {
    id: string;
    code: string;
    label: string;
    category: string;
    categoryLabel: string;
    online: boolean;
    index: number;
    total: number;
    /** Seconds until a shot camera comes back online */
    remaining?: number;
    /** End time derived from remaining (Date.now based) */
    offlineUntil?: number;
}

export interface Hud {
    heading: number;
    pan: number;
    tilt: number;
    fov: number;
    zoom: number;
    zoomLevel: number;
    /** [year, month, day, hour, minute, second] (game clock mode only) */
    clock?: number[];
}

export type TargetStatus = 'scanning' | 'matching' | 'far' | 'masked' | 'obscured' | 'identified';

export interface Identity {
    name?: string;
    birthdate?: string;
    gender?: number;
    nationality?: string;
    citizenid?: string;
    job?: string;
    phone?: string;
}

export interface Target {
    id: number;
    status: TargetStatus;
    distance: number;
    scanTime: number;
    scanKey: number;
    data?: Identity;
    photo?: string;
}

export interface LogEntry {
    key: string;
    id: number;
    status: 'identified' | 'masked';
    name: string;
    camera: string;
    time: string;
}

export interface OpenPayload {
    locales?: Record<string, string>;
    ui?: UIConfig;
    categories?: Category[];
    cameras?: CameraItem[];
}

const mockCameras = (): CameraItem[] => {
    const list: [string, string, string, string][] = [
        ['pacific_lobby', 'Pacific Standard - Lobby', 'bank', 'Banks'],
        ['pacific_entrance', 'Pacific Standard - Entrance', 'bank', 'Banks'],
        ['fleeca_legion', 'Fleeca - Legion Square', 'bank', 'Banks'],
        ['fleeca_hawick', 'Fleeca - Hawick Ave', 'bank', 'Banks'],
        ['247_innocence', '24/7 - Innocence Blvd', 'store', '24/7 Stores'],
        ['247_clinton', '24/7 - Clinton Ave', 'store', '24/7 Stores'],
        ['247_sandy', '24/7 - Alhambra Dr', 'store', '24/7 Stores'],
        ['ltd_grove', 'LTD - Grove Street', 'ltd', 'LTD Gasoline'],
        ['ltd_littleseoul', 'LTD - Little Seoul', 'ltd', 'LTD Gasoline'],
        ['robs_prosperity', "Rob's Liquor - Prosperity St", 'liquor', 'Liquor Stores'],
        ['vangelico_1', 'Vangelico - Entrance', 'jewelry', 'Jewelry Stores'],
        ['vangelico_2', 'Vangelico - West Displays', 'jewelry', 'Jewelry Stores'],
    ];

    return list.map(([id, label, category, categoryLabel], i) => ({
        id, label, category, categoryLabel,
        code: `CAM-${String(i + 1).padStart(2, '0')}`,
        online: id !== 'fleeca_hawick' && id !== 'ltd_grove',
        remaining: id === 'ltd_grove' ? 1142 : undefined,
        index: i + 1,
        total: list.length,
    }));
};

const mockCategories: Category[] = [
    { id: 'bank', label: 'Banks', icon: 'bank' },
    { id: 'store', label: '24/7 Stores', icon: 'store' },
    { id: 'ltd', label: 'LTD Gasoline', icon: 'fuel' },
    { id: 'liquor', label: 'Liquor Stores', icon: 'bottle' },
    { id: 'jewelry', label: 'Jewelry Stores', icon: 'gem' },
];

/** Flattens nested keys, like ox_lib's lib.getLocales() output, into "a.b.c" form */
const flatten = (source: Record<string, unknown>, prefix = '', out: Record<string, string> = {}): Record<string, string> => {
    for (const [key, value] of Object.entries(source)) {
        const path = prefix ? `${prefix}.${key}` : key;
        if (value && typeof value === 'object') flatten(value as Record<string, unknown>, path, out);
        else out[path] = String(value);
    }
    return out;
};

const withUntil = (cameras: CameraItem[]): CameraItem[] => cameras.map((camera) => ({
    ...camera,
    offlineUntil: camera.remaining != null ? Date.now() + camera.remaining * 1000 : undefined,
}));

const defaultHud = (): Hud => ({ heading: 213.4, pan: 0, tilt: -35, fov: 60, zoom: 1, zoomLevel: 0.15 });

const LOG_LIMIT = 6;
const LOG_REPEAT_MS = 60_000;
const logSeen = new Map<string, number>();

let errorTimer: ReturnType<typeof setTimeout> | undefined;

export const useCameraStore = defineStore('Camera', {
    state: () => ({
        mode: (isNative ? 'hidden' : 'menu') as Mode,
        locales: (isNative ? {} : flatten(previewLocale)) as Record<string, string>,
        ui: { brand: 'LSPD CCTV', locale: 'tr-TR', clock: 'real' } as UIConfig,
        categories: mockCategories,
        cameras: withUntil(mockCameras()),
        category: 'all',
        search: '',
        busy: false,
        error: null as string | null,
        camera: null as CameraItem | null,
        connecting: false,
        signalLost: false,
        signalUntil: null as number | null,
        hud: defaultHud(),
        target: null as Target | null,
        logs: [] as LogEntry[],
    }),
    getters: {
        locale: (state) => (key: string, ...args: (string | number)[]): string => {
            const text = state.locales[key] ?? key;
            if (!args.length) return text;

            let index = 0;
            return text.replace(/%[sd]/g, () => String(args[index++] ?? ''));
        },
        filtered(state): CameraItem[] {
            const query = state.search.trim().toLocaleLowerCase(state.ui.locale);
            return state.cameras.filter((camera) => {
                if (state.category !== 'all' && camera.category !== state.category) return false;
                if (!query) return true;
                return `${camera.code} ${camera.label} ${camera.categoryLabel}`.toLocaleLowerCase(state.ui.locale).includes(query);
            });
        },
        onlineCount(state): number {
            return state.cameras.filter((camera) => camera.online).length;
        },
        countOf: (state) => (category: string): number =>
            category === 'all' ? state.cameras.length : state.cameras.filter((camera) => camera.category === category).length,
    },
    actions: {
        Open(payload: OpenPayload) {
            this.locales = payload.locales ?? {};
            if (payload.ui) this.ui = payload.ui;
            if (payload.categories) this.categories = payload.categories;
            if (payload.cameras) this.cameras = withUntil(payload.cameras);

            this.category = 'all';
            this.search = '';
            this.logs = [];
            logSeen.clear();
            this.ShowMenu();
        },
        ShowMenu(cameras?: CameraItem[]) {
            if (cameras) this.cameras = withUntil(cameras);
            this.mode = 'menu';
            this.camera = null;
            this.target = null;
            this.connecting = false;
            this.signalLost = false;
            this.busy = false;
            this.error = null;
        },
        SetCameras(cameras: CameraItem[]) {
            this.cameras = withUntil(cameras);
        },
        Hide() {
            this.mode = 'hidden';
            this.camera = null;
            this.target = null;
            this.busy = false;
            this.error = null;
        },
        CloseUI() {
            if (this.mode === 'hidden') return;
            this.Hide();
            FetchNUI('nui/close');
        },
        Connecting(camera: CameraItem) {
            this.mode = 'view';
            this.camera = camera;
            this.connecting = true;
            this.signalLost = false;
            this.target = null;
            this.hud = { ...defaultHud(), heading: this.hud.heading };
        },
        View(camera: CameraItem) {
            this.mode = 'view';
            this.camera = camera;
            this.connecting = false;
            this.busy = false;
        },
        SetSignal(lost: boolean, remaining?: number) {
            this.signalLost = lost;
            this.signalUntil = lost && remaining != null ? Date.now() + remaining * 1000 : null;
            if (lost) this.target = null;
        },
        SetHud(hud: Hud) {
            this.hud = hud;
        },
        SetTarget(target: Target | null) {
            this.target = target;
            if (target) this.Log(target);
        },
        Log(target: Target) {
            if (target.status !== 'identified' && target.status !== 'masked') return;

            const key = `${target.id}:${target.status}:${this.camera?.id}`;
            const now = Date.now();
            if (now - (logSeen.get(key) ?? 0) < LOG_REPEAT_MS) return;
            logSeen.set(key, now);

            const date = new Date();
            const time = [date.getHours(), date.getMinutes(), date.getSeconds()].map((n) => String(n).padStart(2, '0')).join(':');

            this.logs.unshift({
                key: `${key}:${now}`,
                id: target.id,
                status: target.status,
                name: target.status === 'identified' ? (target.data?.name || `#${target.id}`) : this.locale('ui.log.masked'),
                camera: this.camera?.code ?? '',
                time,
            });
            if (this.logs.length > LOG_LIMIT) this.logs.length = LOG_LIMIT;
        },
        SetError(error: string) {
            this.error = error;
            clearTimeout(errorTimer);
            errorTimer = setTimeout(() => (this.error = null), 3500);
        },
        async Connect(camera: CameraItem) {
            if (this.busy || !camera.online) return;

            this.busy = true;
            this.error = null;

            if (!isNative) {
                this.Connecting(camera);
                setTimeout(() => this.View(camera), 900);
                return;
            }

            const response = await FetchNUI('nui/view', { id: camera.id });
            this.busy = false;

            if (!response.success && response.error !== 'cancelled') {
                this.SetError(response.error ?? 'invalid');
            }
        },
    },
});
