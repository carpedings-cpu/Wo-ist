/* Wo ist's? · Autorin: Diana Ziegler · Supabase-Attrappe für die Browser-Tests */
window.supabase = {
  createClient(url) {
    const uid = () => 'haushalt';
    const post = (pfad, body) => fetch(url + pfad, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
    }).then(r => r.json());
    const fehler = r => (r.error ? { message: r.error } : null);
    const zuB64 = blob => new Promise(ok => { const f = new FileReader(); f.onload = () => ok(f.result.split(',')[1]); f.readAsDataURL(blob); });
    return {
      from() {
        const q = {
          ab: '',
          select() { return q; },
          gt(_, v) { q.ab = v; return q; },
          order() { return q; },
          then(ok, nein) { return post('/rows', { uid: uid(), ab: q.ab }).then(r => ({ data: r.rows, error: fehler(r) })).then(ok, nein); },
          upsert: row => post('/upsert', { uid: uid(), row }).then(r => ({ error: fehler(r) }))
        };
        return q;
      },
      storage: {
        from: () => ({
          upload: async (path, blob) => ({ error: fehler(await post('/storage/put', { uid: uid(), path, b64: await zuB64(blob), type: blob.type })) }),
          download: async path => {
            const r = await post('/storage/get', { uid: uid(), path });
            if (r.error) return { data: null, error: fehler(r) };
            return { data: new Blob([Uint8Array.from(atob(r.b64), z => z.charCodeAt(0))], { type: r.type }), error: null };
          },
          remove: async paths => ({ error: fehler(await post('/storage/remove', { uid: uid(), paths })) })
        })
      }
    };
  }
};
