<script lang="ts">
  interface Props {
    loading: boolean;
    hasVectors: boolean;
    error: string | null;
    mode: "live" | "historical";
    loadPct: number;
    loadStatus: string;
    onFetchData: () => void;
    onSwitchToHistorical: () => void;
  }

  let { loading, hasVectors, error, mode, loadPct, loadStatus, onFetchData, onSwitchToHistorical }: Props = $props();
</script>

{#if loading && !hasVectors}
  <div class="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-base-100">
    <progress class="progress progress-primary w-48" value={loadPct} max="100"></progress>
    <span class="text-xs opacity-50">{loadStatus}</span>
  </div>
{:else if error}
  <div class="absolute inset-0 flex items-center justify-center bg-base-100">
    <div class="text-center flex flex-col items-center gap-2">
      <p class="font-semibold text-error">Failed to load data</p>
      <p class="text-sm text-error opacity-70">{error}</p>
      <button onclick={onSwitchToHistorical} class="btn btn-sm bg-base-content text-base-100 border-base-content mt-1">Load Historical</button>
    </div>
  </div>
{:else if mode === "live" && !loading && !hasVectors}
  <div class="absolute inset-0 flex items-center justify-center bg-base-100">
    <div class="text-center flex flex-col items-center gap-3 max-w-xs">
      <p class="text-sm opacity-70">Live queries can be slow or fail under load.</p>
      <button onclick={onFetchData} class="btn btn-sm bg-base-content text-base-100 border-base-content">Query Live Data</button>
    </div>
  </div>
{/if}
