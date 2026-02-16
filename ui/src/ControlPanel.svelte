<script lang="ts">
  import { RefreshCw } from "lucide-svelte";
  import { timeAgo } from "./lib/utils";

  interface Props {
    mode: "live" | "historical";
    isPlaying: boolean;
    histDates: string[];
    selectedDateIdx: number;
    selectedDate: string;
    sliderPct: number;
    speedIdx: number;
    interp: number;
    animEnabled: boolean;
    loading: boolean;
    lastUpdated: Date | null;
    isDemo: boolean;
    speedLabels: readonly string[];
    onTogglePlay: () => void;
    onSliderChange: (idx: number) => void;
    onCycleSpeed: () => void;
    onInterpChange: (val: number) => void;
    onToggleAnim: () => void;
    onSwitchMode: (mode: "live" | "historical") => void;
    onFetchData: () => void;
    onShowInfo: () => void;
  }

  let {
    mode, isPlaying, histDates, selectedDateIdx, selectedDate, sliderPct,
    speedIdx, interp, animEnabled, loading, lastUpdated, isDemo, speedLabels,
    onTogglePlay, onSliderChange, onCycleSpeed, onInterpChange,
    onToggleAnim, onSwitchMode, onFetchData, onShowInfo,
  }: Props = $props();
</script>

<div class="panel-controls absolute bottom-2 right-2 flex items-center gap-1.5 bg-base-100/80 backdrop-blur-sm rounded px-2.5 py-1.5 max-w-[min(36rem,calc(100vw-1rem))]">
  {#if mode === "historical"}
    <button tabindex="-1" onclick={onTogglePlay} class="opacity-50 hover:opacity-100 transition-opacity" title={isPlaying ? "Pause" : "Play"}>
      {#if isPlaying}
        <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><rect x="5" y="3" width="4" height="18"/><rect x="15" y="3" width="4" height="18"/></svg>
      {:else}
        <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><polygon points="5,3 19,12 5,21"/></svg>
      {/if}
    </button>
    <input
      type="range"
      min="0"
      max={Math.max(0, histDates.length - 1)}
      value={selectedDateIdx}
      oninput={(e) => onSliderChange(Number(e.currentTarget.value))}
      class="hist-slider hidden sm:block sm:flex-1 sm:min-w-48"
      style="background:linear-gradient(to right,rgba(255,255,255,0.7) {sliderPct}%,rgba(255,255,255,0.15) {sliderPct}%)"
    />
    <div class="flex items-center gap-1 sm:hidden">
      <button tabindex="-1" onclick={() => onSliderChange(Math.max(0, selectedDateIdx - 1))} class="opacity-50 hover:opacity-100 transition-opacity text-[10px]">&#8249;</button>
      <span class="text-[10px] opacity-60">{selectedDate}</span>
      <button tabindex="-1" onclick={() => onSliderChange(Math.min(histDates.length - 1, selectedDateIdx + 1))} class="opacity-50 hover:opacity-100 transition-opacity text-[10px]">&#8250;</button>
    </div>
    <span class="text-[10px] opacity-60 whitespace-nowrap hidden sm:inline">{selectedDate}</span>
    <span class="opacity-20">&middot;</span>
    <button tabindex="-1" onclick={onCycleSpeed} class="text-[10px] opacity-50 hover:opacity-80 transition-opacity tabular-nums" title="Playback speed">{speedLabels[speedIdx]}</button>
    <span class="opacity-20">&middot;</span>
    <select
      tabindex="-1"
      class="text-[10px] opacity-50 bg-transparent outline-none appearance-none border-none"
      title="Interpolation factor"
      value={interp}
      onchange={(e) => onInterpChange(Number(e.currentTarget.value))}
    >
      {#each [1, 2, 3, 4, 5] as v}
        <option value={v}>&times;{v}</option>
      {/each}
    </select>
    <span class="opacity-20">&middot;</span>
    <button tabindex="-1" onclick={onToggleAnim} class="text-[10px] transition-opacity {animEnabled ? 'opacity-70' : 'opacity-40 hover:opacity-60'}" title="Animate transitions">Animate</button>
    <span class="opacity-20">&middot;</span>
    <button tabindex="-1" onclick={onShowInfo} class="text-[10px] opacity-40 hover:opacity-80 transition-opacity" title="About this project">Info</button>
    <span class="opacity-20">&middot;</span>
    <button tabindex="-1" onclick={() => onSwitchMode("live")} class="text-[10px] opacity-40 hover:opacity-80 transition-opacity">Live &rarr;</button>
  {:else}
    {#if isDemo}
      <span class="text-[10px] font-medium text-warning">DEMO</span>
      <span class="opacity-20">&middot;</span>
    {/if}
    {#if lastUpdated}
      <span class="text-[10px] opacity-60">{lastUpdated.toLocaleTimeString("en-GB", { timeZone: "Asia/Seoul", hour: "2-digit", minute: "2-digit" })} KST {#if isDemo} ({timeAgo(lastUpdated)}){/if}</span>
      <span class="opacity-20">&middot;</span>
    {/if}
    <select
      tabindex="-1"
      class="text-[10px] opacity-50 bg-transparent outline-none appearance-none border-none"
      title="Interpolation factor"
      value={interp}
      onchange={(e) => onInterpChange(Number(e.currentTarget.value))}
    >
      {#each [1, 2, 3, 4, 5] as v}
        <option value={v}>&times;{v}</option>
      {/each}
    </select>
    <span class="opacity-20">&middot;</span>
    <button tabindex="-1" class="opacity-50 hover:opacity-100 transition-opacity disabled:opacity-20" onclick={onFetchData} disabled={loading} title="Refresh">
      <RefreshCw size={12} class={loading ? "animate-spin" : ""} />
    </button>
    <span class="opacity-20">&middot;</span>
    <button tabindex="-1" onclick={onShowInfo} class="text-[10px] opacity-40 hover:opacity-80 transition-opacity" title="About this project">Info</button>
    <span class="opacity-20">&middot;</span>
    <button tabindex="-1" onclick={() => onSwitchMode("historical")} class="text-[10px] opacity-40 hover:opacity-80 transition-opacity">Historical &rarr;</button>
  {/if}
</div>

<style>
  .hist-slider {
    -webkit-appearance: none;
    appearance: none;
    height: 4px;
    border-radius: 2px;
    outline: none;
    cursor: pointer;
  }
  .hist-slider::-webkit-slider-thumb {
    -webkit-appearance: none;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: white;
    cursor: pointer;
  }
  .hist-slider::-moz-range-thumb {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: white;
    border: none;
    cursor: pointer;
  }
  :global(.panel-controls button),
  :global(.panel-controls select) {
    cursor: pointer;
  }
  :global(.panel-controls button:disabled) {
    cursor: default;
  }
  :global(.panel-controls button:focus),
  :global(.panel-controls select:focus) {
    outline: none;
    box-shadow: none;
  }
</style>
