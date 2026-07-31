Translucent fixed header for every screen: back button, wordless centre slot, grown-ups door.

```jsx
<TopBar onBack={goBack} onSettings={openGrownups} center={<QuizProgress total={5} done={2} current={2} />} />
```

Only grown-up screens get a `title`; kid screens keep the centre wordless.
