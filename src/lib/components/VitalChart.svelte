<script>
  let { observations = [] } = $props();

  const series = $derived([
    {
      label: 'Suhu (°C)',
      color: '#dc2626',
      values: observations.map(o => o.temperature)
    },
    {
      label: 'Nadi (x/mnt)',
      color: '#2563eb',
      values: observations.map(o => o.heart_rate)
    },
    {
      label: 'RR (x/mnt)',
      color: '#7c3aed',
      values: observations.map(o => o.respiratory_rate)
    },
    {
      label: 'SPO2 (%)',
      color: '#059669',
      values: observations.map(o => o.spo2)
    }
  ]);

  const labels = $derived(
    observations.map(o =>
      new Date(o.observed_at || o.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
    )
  );

  const charts = $derived(
    series
      .filter(s => s.values.some(v => v !== null && v !== undefined))
      .map(item => {
        const nums = item.values.filter(v => v !== null && v !== undefined);
        const min = Math.min(...nums);
        const max = Math.max(...nums);
        const span = (max - min) || 1;
        const pad = span * 0.15;
        const low = min - pad;
        const high = max + pad;
        const range = (high - low) || 1;

        const pts = item.values.map((v, i) => {
          if (v === null || v === undefined) return null;
          const x = nums.length <= 1 ? 150 : 15 + (i / (nums.length - 1)) * 270;
          const y = 75 - ((v - low) / range) * 65;
          return `${x},${y}`;
        }).filter(Boolean);

        const lastVal = item.values[item.values.length - 1];
        let lastPoint = null;
        if (lastVal !== null && lastVal !== undefined) {
          const x = nums.length <= 1 ? 150 : 15 + ((item.values.length - 1) / (nums.length - 1)) * 270;
          const y = 75 - ((lastVal - low) / range) * 65;
          lastPoint = { x, y };
        }

        return { ...item, pts: pts.join(' '), lastVal, lastPoint };
      })
  );
</script>

{#if observations.length > 1}
  <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
    {#each charts as item}
      <div class="border border-gray-200 rounded-xl p-3">
        <p class="text-xs font-medium text-gray-500 mb-2">{item.label}</p>
        <svg viewBox="0 0 300 90" class="w-full h-24" preserveAspectRatio="none">
          <polyline
            points={item.pts}
            fill="none"
            stroke={item.color}
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            vector-effect="non-scaling-stroke"
          />
          {#if item.lastPoint}
            <circle cx={item.lastPoint.x} cy={item.lastPoint.y} r="4" fill={item.color} />
          {/if}
        </svg>
        <div class="flex items-center justify-between mt-1">
          <span class="text-[10px] text-gray-400">Awal: {labels[0]}</span>
          <span class="text-[10px] text-gray-400">Terakhir: {labels[labels.length - 1]}</span>
        </div>
        <p class="text-sm font-semibold text-gray-900 mt-1">
          {item.lastVal?.toLocaleString('id-ID') ?? '-'}
        </p>
      </div>
    {/each}
  </div>
{:else}
  <p class="text-sm text-gray-400 text-center py-6">Tambahkan minimal 2 observasi untuk melihat grafik tren.</p>
{/if}
