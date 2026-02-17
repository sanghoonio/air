<script lang="ts">
</script>

<dialog id="info-modal" class="modal">
  <div class="modal-box max-w-lg bg-base-100 text-base-content">
    <h3 class="font-semibold text-lg mb-3">About this project</h3>
    <div class="prose prose-sm opacity-80">
      <p>
        I built this to visualize how wind patterns carry air pollution across
        Northeast Asia. While yellow dust has been a geological phenomenon for 
        millennia, some Koreans are still quick to blame China for our 
        air quality issues. I still see the sentiment reinforced online. It
        even came up visiting relatives in Korea for the first time in 15
        years. Just how much of the dust is actually from Central Asian
        deserts, Chinese manufacturing hubs, or Korea itself?
        Perhaps this map can help answer that.
      </p>
      <p>
        The historical mode scrubs through daily snapshots in 2025 so you can 
        watch seasonal shifts and pollution events unfold. Live mode pulls 
        real-time forecasts from <a href="https://open-meteo.com" target="_blank" rel="noopener">Open-Meteo</a>.
      </p>
    </div>
    <div class="modal-action">
      <form method="dialog">
        <button class="btn btn-sm btn-ghost">Close</button>
      </form>
    </div>
  </div>
  <form method="dialog" class="modal-backdrop"><button>close</button></form>
</dialog>
