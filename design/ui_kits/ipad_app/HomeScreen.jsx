const { TopBar, HomeTile, Wordmark, Badge, IconButton } = window.ZilpZalpDesignSystem_bd8c6b;

/* Home = the tree. Nests (activities) sit on branches; the crown is cream sky. */
function HomeScreen({ go, stars }) {
  return (
    <div style={{ minHeight: '100%', display: 'flex', flexDirection: 'column', background: 'linear-gradient(180deg, var(--orange-50) 0%, var(--cream-100) 46%, var(--olive-100) 100%)' }}>
      <TopBar onSettings={() => go('grownups')} center={<Wordmark size={44} />} />
      <div style={{ flex: 1, position: 'relative', padding: '32px var(--gutter-screen) 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 26 }}>
          <h1 style={{ margin: 0, font: 'var(--weight-black) var(--text-display-2)/var(--lh-display-2) var(--font-display)', color: 'var(--text-strong)' }}>Was möchtest du machen?</h1>
          <Badge tone="sun" icon="star">{stars} Sterne</Badge>
        </div>
        {/* trunk + branches, drawn with plain blocks (no illustration art yet) */}
        <div style={{ position: 'relative', height: 470 }}>
          <div style={{ position: 'absolute', left: '50%', bottom: 0, width: 92, height: 400, marginLeft: -46, background: 'var(--bark-500)', borderRadius: '40px 40px 0 0' }} />
          <div style={{ position: 'absolute', left: '50%', bottom: 250, width: 300, height: 34, marginLeft: -300, background: 'var(--bark-500)', borderRadius: 'var(--radius-pill)' }} />
          <div style={{ position: 'absolute', left: '50%', bottom: 170, width: 300, height: 34, background: 'var(--bark-500)', borderRadius: 'var(--radius-pill)' }} />
          <div style={{ position: 'relative', display: 'grid', gridTemplateColumns: 'repeat(2, 240px)', justifyContent: 'space-between', rowGap: 40 }}>
            <HomeTile icon="volume-2" label="Wer singt da?" tone="leaf" stars={3} onOpen={() => go('quiz')} />
            <HomeTile icon="bird" label="Wer ist das?" tone="hoopoe" stars={2} onOpen={() => go('quiz')} />
            <HomeTile icon="feather" label="Federn finden" tone="clay" stars={1} onOpen={() => go('quiz')} />
            <HomeTile label="Bald!" locked />
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', gap: 'var(--space-5)', padding: '0 0 var(--space-6)' }}>
        <IconButton icon="album" label="Meine Sammlung" tone="primary" onClick={() => go('collection')} />
        <IconButton icon="map" label="Karte" tone="clay" />
        <IconButton icon="music" label="Lieder" tone="accent" />
      </div>
    </div>
  );
}
Object.assign(window, { HomeScreen });
