const { RewardSticker, Button, Wordmark } = window.ZilpZalpDesignSystem_bd8c6b;
const ZZ = (window.ZZ_BIRDS || []).find(b => b.slug === 'zilpzalp') || {};

/* Celebration: one new sticker, two ways out. Full-bleed forest green. */
function RewardScreen({ go }) {
  return (
    <div style={{ minHeight: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 'var(--space-6)', background: 'var(--surface-forest)', textAlign: 'center', padding: 'var(--gutter-screen)' }}>
      <div style={{ display: 'flex', gap: 10 }}>
        {[0, 1, 2].map(i => (
          <span key={i} style={{ width: 26, height: 26, borderRadius: '999px', background: 'var(--sun-400)', animation: `zz-bob 1.4s var(--ease-in-out) ${i * 0.15}s infinite` }} />
        ))}
      </div>
      <h1 style={{ margin: 0, font: 'var(--weight-black) var(--text-hero)/var(--lh-hero) var(--font-display)', color: 'var(--white)' }}>Gut gemacht!</h1>
      <div style={{ animation: 'zz-pop var(--dur-celebrate) var(--ease-bounce) both' }}>
        <RewardSticker photo={ZZ.photo} credit={ZZ.credit} label={(ZZ.name || 'Zilpzalp') + ' gesammelt'} tone="sun" size={200} />
      </div>
      <div style={{ display: 'flex', gap: 'var(--space-5)' }}>
        <Button tone="reward" size="lg" icon="album" onClick={() => go('collection')}>Sammlung</Button>
        <Button tone="primary" size="lg" iconRight="arrow-right" onClick={() => go('quiz')}>Nochmal spielen</Button>
      </div>
      <Wordmark size={34} tone="mono-light" style={{ opacity: 0.55 }} />
    </div>
  );
}
Object.assign(window, { RewardScreen });
