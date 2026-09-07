const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const model = {};
vm.createContext(model);
vm.runInContext(fs.readFileSync(require('node:path').join(__dirname,'../Model.js'),'utf8').replace(/^\.pragma library\s*/,''),model);

test('search supports case, punctuation, multiple tokens, and fuzzy abbreviations',()=>{
  assert(model.score('Starfall: Afterlight','STAR after')>0);
  assert(model.score('Starfall: Afterlight','sfl')>0);
  assert.equal(model.score('Starfall: Afterlight','rain'),0);
  assert(model.score('Star','st')>model.score('Moon Star','st'));
});
test('hidden games require the explicit hidden filter',()=>{
  const games=[{id:'1',name:'Quest',hidden:true,favorite:true},{id:'2',name:'Moon',hidden:false}];
  assert.equal(model.filter(games,'','all').length,1);
  assert.equal(model.filter(games,'','favorites').length,0);
  assert.equal(model.filter(games,'','hidden')[0].id,'1');
});
test('session tags are explicit and notes form their own pool',()=>{
  const games=model.demoLibrary().games;
  assert(model.filter(games,'','quick').every(g=>g.mood==='quick'));
  assert(model.filter(games,'','notes').every(g=>g.note.length>0));
  assert.equal(model.filter(games,'notinstalled','all').length,0);
});
test('unknown and future Steam timestamps are described honestly',()=>{
  assert.equal(model.lastPlayed(0,1700000000000),'No play recorded by Steam');
  assert.equal(model.lastPlayed(1800000000,1700000000000),'Played today');
  assert.equal(model.sizeLabel(0),'Size unknown');
});
test('demo fixture contains only fictional, offline games with stable identities',()=>{
  const games=model.demoLibrary().games;
  assert.equal(new Set(games.map(g=>g.id)).size,games.length);
  assert(games.every(g=>g.cover===''));
  assert.equal(model.byId(games,'missing'),null);
});
