<script lang="ts">
  import { AQI_BANDS } from "./lib/aqi";
</script>

<!-- Wide: bottom-left horizontal -->
<div class="absolute bottom-2 left-2 lg:flex hidden items-center gap-1.5 bg-base-100/80 backdrop-blur-sm rounded px-2.5 py-1.5">
  {#each AQI_BANDS as band}
    <span class="w-2 h-2 rounded-full shrink-0" style="background-color: {band.color};" title={band.label}></span>
    <span class="text-[10px] opacity-60">{band.label}</span>
  {/each}
  <span class="text-[10px] opacity-40 ml-0.5">US AQI</span>
</div>

<!-- Narrow: top-right vertical -->
<div class="absolute top-2 right-2 lg:hidden flex flex-col gap-1 bg-base-100/80 backdrop-blur-sm rounded px-2 py-1.5">
  <span class="text-[10px] opacity-40">US AQI</span>
  {#each AQI_BANDS as band}
    <div class="flex items-center gap-1.5">
      <span class="w-2 h-2 rounded-full shrink-0" style="background-color: {band.color};" title={band.label}></span>
      <span class="text-[10px] opacity-60">{band.label}</span>
    </div>
  {/each}
</div>
