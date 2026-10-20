import { useCameraStore, type CameraItem, type Hud, type OpenPayload, type Target, type TargetStatus } from "../store/index";
import { isNative } from "./index";

interface NuiMessage {
    action: string;
    payload: any;
}

export function messageEvent() {
    const handlers: Record<string, (payload: any) => void> = {
        'nui/open': (payload: OpenPayload) => useCameraStore().Open(payload ?? {}),
        'nui/hide': () => useCameraStore().Hide(),
        'nui/menu': (payload: { cameras?: CameraItem[] }) => useCameraStore().ShowMenu(payload?.cameras),
        'nui/cameras': (payload: { cameras: CameraItem[] }) => useCameraStore().SetCameras(payload.cameras),
        'nui/connecting': (payload: CameraItem) => useCameraStore().Connecting(payload),
        'nui/view': (payload: CameraItem) => useCameraStore().View(payload),
        'nui/signal': (payload: { lost: boolean; remaining?: number }) => useCameraStore().SetSignal(!!payload?.lost, payload?.remaining),
        'nui/hud': (payload: Hud) => useCameraStore().SetHud(payload),
        'nui/target': (payload: Target | false) => useCameraStore().SetTarget(payload || null),
    };

    window.addEventListener('message', ({ data }: MessageEvent<NuiMessage>) => {
        const handler = handlers[data?.action];

        if (handler) {
            handler(data.payload);
        } else {
            console.warn(`Unknown action received: ${data?.action}`);
        }
    });
};

export function keydownEvent() {
    window.addEventListener("keydown", ({ code }) => {
        const store = useCameraStore();

        if (code === "Escape") {
            if (store.mode !== 'menu' || store.busy) return;
            if (store.search) store.search = '';
            else store.CloseUI();
            return;
        }

        if (!isNative && store.mode === 'view') browserPreview(code);
    });

    if (!isNative) {
        window.addEventListener("wheel", ({ deltaY }) => {
            const store = useCameraStore();
            if (store.mode !== 'view') return;

            const fov = Math.min(70, Math.max(7, store.hud.fov * (deltaY < 0 ? 1 / 1.18 : 1.18)));
            store.SetHud({ ...store.hud, fov, zoom: 60 / fov, zoomLevel: (70 - fov) / 63 });
        });
    }
};

const mockTarget = (status: TargetStatus): Target => ({
    id: 14,
    status,
    distance: status === 'far' ? 24.6 : 7.3,
    scanTime: 1800,
    scanKey: Date.now(),
    data: status === 'identified' ? {
        name: 'Jonathan Miller',
        birthdate: '1994-03-12',
        gender: 0,
        nationality: 'American',
        citizenid: 'KXR48291',
        job: 'Taxi Driver',
    } : undefined,
});

/** Browser preview (outside the game): 1-6 target states, 0 no target, L signal, Backspace list */
function browserPreview(code: string) {
    const store = useCameraStore();
    const statuses: Record<string, TargetStatus> = {
        Digit1: 'scanning', Digit2: 'matching', Digit3: 'identified', Digit4: 'masked', Digit5: 'obscured', Digit6: 'far',
    };

    if (statuses[code]) return store.SetTarget(mockTarget(statuses[code]));
    if (code === 'Digit0') return store.SetTarget(null);
    if (code === 'KeyL') return store.SetSignal(!store.signalLost, 1200);
    if (code === 'Backspace') return store.ShowMenu();

    const hud = { ...store.hud };
    if (code === 'KeyA') { hud.heading = (hud.heading + 357) % 360; hud.pan -= 3; }
    if (code === 'KeyD') { hud.heading = (hud.heading + 3) % 360; hud.pan += 3; }
    if (code === 'KeyW') hud.tilt = Math.min(10, hud.tilt + 3);
    if (code === 'KeyS') hud.tilt = Math.max(-80, hud.tilt - 3);
    store.SetHud(hud);
}
