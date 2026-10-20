const resourceName = (): string => (window as any).GetParentResourceName?.() ?? 'hype-camera';

export const isNative = !!(window as any).invokeNative;

interface NuiResponse<T = unknown> {
    success: boolean;
    error?: string;
    data?: T;
};

export async function FetchNUI<T = unknown>(event: string, data?: unknown, mock?: T): Promise<NuiResponse<T>> {
    if (!isNative) {
        return { success: true, data: mock };
    }

    const response = await fetch(`https://${resourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data ?? {}),
    });

    return response.json();
};

export const pad = (value: number, length = 2): string => String(Math.trunc(Math.abs(value))).padStart(length, '0');

/** Signed, fixed width angle/number display (e.g. +012.5) */
export const signed = (value: number, digits = 3, decimals = 1): string => {
    const sign = value < 0 ? '-' : '+';
    const [whole, fraction] = Math.abs(value).toFixed(decimals).split('.');
    return `${sign}${whole.padStart(digits, '0')}${fraction ? '.' + fraction : ''}`;
};

/** Remaining time (ms) -> "MM:SS" */
export const countdown = (ms: number): string => {
    const total = Math.max(0, Math.ceil(ms / 1000));
    return `${pad(Math.floor(total / 60))}:${pad(total % 60)}`;
};

/** "Match rate" that stays fixed per identity (the same person always gets the same rate) */
export const matchRate = (id: number): string => (93 + ((id * 7919) % 67) / 10).toFixed(1);
