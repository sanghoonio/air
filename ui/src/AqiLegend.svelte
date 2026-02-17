<script lang="ts">
  import type { AqiBand, MetricKey } from "./lib/types";
  import { VARIABLE_CONFIGS } from "./lib/variables";

  interface Props {
    bands: AqiBand[];
    selectedMetric: MetricKey;
    onSelectMetric: (key: MetricKey) => void;
  }

  let { bands, selectedMetric, onSelectMetric }: Props = $props();
</script>

<!-- Wide: bottom-left horizontal -->
<div class="absolute bottom-2 left-2 lg:flex hidden items-center gap-1.5 bg-base-100/80 backdrop-blur-sm rounded px-2.5 py-1.5">
  {#each bands as band}
    <span class="w-2 h-2 rounded-full shrink-0" style="background-color: {band.color};" title={band.label}></span>
    <span class="text-[10px] opacity-60">{band.label}</span>
  {/each}
  <select
    class="text-[10px] opacity-40 hover:opacity-70 ml-0.5 bg-transparent outline-none appearance-none border-none cursor-pointer" style="field-sizing:content"
    value={selectedMetric}
    onchange={(e) => onSelectMetric(e.currentTarget.value as MetricKey)}
  >
    {#each VARIABLE_CONFIGS as v}
      <option value={v.key}>{v.label}{v.unit ? ` (${v.unit})` : ""}</option>
    {/each}
  </select>
</div>

<!-- Narrow: top-right vertical -->
<div class="absolute top-2 right-2 lg:hidden flex flex-col gap-1 bg-base-100/80 backdrop-blur-sm rounded px-2 py-1.5">
  <select
    class="text-[10px] opacity-40 hover:opacity-70 bg-transparent outline-none appearance-none border-none cursor-pointer" style="field-sizing:content"
    value={selectedMetric}
    onchange={(e) => onSelectMetric(e.currentTarget.value as MetricKey)}
  >
    {#each VARIABLE_CONFIGS as v}
      <option value={v.key}>{v.label}{v.unit ? ` (${v.unit})` : ""}</option>
    {/each}
  </select>
  {#each bands as band}
    <div class="flex items-center gap-1.5">
      <span class="w-2 h-2 rounded-full shrink-0" style="background-color: {band.color};" title={band.label}></span>
      <span class="text-[10px] opacity-60">{band.label}</span>
    </div>
  {/each}
</div>
