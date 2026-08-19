/**
 * Jest 全局环境桩。
 * RN preset 已把 global.window 定义为 globalThis 别名（无事件 API）；
 * React 19 react-test-renderer 的全局错误上报依赖 window.dispatchEvent，
 * 此处补齐最小事件桩。
 */
if (typeof global.window !== 'undefined') {
  if (typeof global.window.dispatchEvent !== 'function') {
    global.window.dispatchEvent = () => {};
  }
  if (typeof global.window.addEventListener !== 'function') {
    global.window.addEventListener = () => {};
  }
  if (typeof global.window.removeEventListener !== 'function') {
    global.window.removeEventListener = () => {};
  }
}
