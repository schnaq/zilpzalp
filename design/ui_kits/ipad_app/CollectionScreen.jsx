const { TopBar, RewardSticker, Card, Badge, Button } = window.ZilpZalpDesignSystem_bd8c6b;

const TONE = ['leaf', 'hoopoe', 'sun', 'leaf', 'rare', 'hoopoe'];
const FOUND = ['zilpzalp', 'wiedehopf', 'amsel', 'blaumeise', 'eisvogel'];
const BIRDS = FOUND.map((slug, i) => {
  const b = (window.ZZ_BIRDS || []).find(x => x.slug === slug) || {};
  return { photo: b.photo, credit: b.credit, label: b.name || slug, tone: TONE[i] };
}).concat([
  { label: 'Noch geheim', locked: true },
  { label: 'Noch geheim', locked: true },
  { label: 'Noch geheim', locked: true },
]);

/* The album: every bird a child has met, plus the empty spots ahead. */
function CollectionScreen({ go }) {
  return (
    <div style={{ minHeight: '100%', background: 'var(--surface-page)' }}>
      <TopBar onBack={() => go('home')} onSettings={() => go('grownups')} title="Meine Sammlung" />
      <div style={{ padding: 'var(--space-6) var(--gutter-screen)' }}>
        <div style={{ display: 'flex', gap: 'var(--space-3)', marginBottom: 'var(--space-6)' }}>
          <Badge tone="leaf" icon="leaf">5 Vögel</Badge>
          <Badge tone="sun" icon="star">11 Sterne</Badge>
          <Badge tone="rare" icon="sparkles">1 seltener Fund</Badge>
        </div>
        <Card tone="paper" pad="var(--space-6)">
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--space-6) var(--space-5)', justifyItems: 'center' }}>
            {BIRDS.map((b, i) => <RewardSticker key={i} {...b} size={150} />)}
          </div>
        </Card>
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: 'var(--space-6)' }}>
          <Button tone="accent" size="lg" icon="play" onClick={() => go('quiz')}>Neuen Vogel finden</Button>
        </div>
      </div>
    </div>
  );
}
Object.assign(window, { CollectionScreen });
