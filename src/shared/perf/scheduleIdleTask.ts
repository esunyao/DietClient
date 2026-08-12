/** 在首帧与原生转场完成后再执行非关键数据请求，可在失焦时取消。 */
export function scheduleIdleTask(callback: () => void): () => void {
  const idle = globalThis as typeof globalThis & {
    requestIdleCallback?: (work: () => void, options?: { timeout: number }) => number;
    cancelIdleCallback?: (handle: number) => void;
  };
  if (idle.requestIdleCallback && idle.cancelIdleCallback) {
    const handle = idle.requestIdleCallback(callback, { timeout: 300 });
    return () => idle.cancelIdleCallback?.(handle);
  }
  const handle = setTimeout(callback, 0);
  return () => clearTimeout(handle);
}
