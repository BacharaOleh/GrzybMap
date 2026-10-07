/**
 * Polish Forestry Dictionary (Słownik Leśny BDL)
 * Maps official codes from Bank Danych o Lasach to human-readable names and traits.
 */

export const SPECIES_CODES = {
  SO: { namePl: 'Sosna zwyczajna', nameRu: 'Сосна обыкновенная', type: 'conifer', icon: '🌲', latin: 'Pinus sylvestris' },
  'ŚW': { namePl: 'Świerk pospolity', nameRu: 'Ель европейская', type: 'conifer', icon: '🌲', latin: 'Picea abies' },
  JD: { namePl: 'Jodła pospolita', nameRu: 'Пихта белая', type: 'conifer', icon: '🌲', latin: 'Abies alba' },
  MD: { namePl: 'Modrzew europejski', nameRu: 'Лиственница', type: 'conifer', icon: '🌲', latin: 'Larix decidua' },
  DB: { namePl: 'Dąb szypułkowy', nameRu: 'Дуб черешчатый', type: 'deciduous', icon: '🌳', latin: 'Quercus robur' },
  'DĄB': { namePl: 'Dąb szypułkowy', nameRu: 'Дуб черешчатый', type: 'deciduous', icon: '🌳', latin: 'Quercus robur' },
  BK: { namePl: 'Buk zwyczajny', nameRu: 'Бук европейский', type: 'deciduous', icon: '🌳', latin: 'Fagus sylvatica' },
  BRZ: { namePl: 'Brzoza brodawkowata', nameRu: 'Берёза повислая', type: 'deciduous', icon: '🌳', latin: 'Betula pendula' },
  OS: { namePl: 'Topola osika', nameRu: 'Осина', type: 'deciduous', icon: '🌳', latin: 'Populus tremula' },
  OL: { namePl: 'Olsza czarna', nameRu: 'Ольха чёрная', type: 'deciduous', icon: '🌳', latin: 'Alnus glutinosa' },
  GB: { namePl: 'Grab pospolity', nameRu: 'Граб обыкновенный', type: 'deciduous', icon: '🌳', latin: 'Carpinus betulus' },
  KL: { namePl: 'Klon zwyczajny', nameRu: 'Клён остролистный', type: 'deciduous', icon: '🌳', latin: 'Acer platanoides' },
  JW: { namePl: 'Jawor', nameRu: 'Клён белый (Явор)', type: 'deciduous', icon: '🌳', latin: 'Acer pseudoplatanus' },
  LP: { namePl: 'Lipa drobnolistna', nameRu: 'Липа мелколистная', type: 'deciduous', icon: '🌳', latin: 'Tilia cordata' },
  JS: { namePl: 'Jesion wyniosły', nameRu: 'Ясень обыкновенный', type: 'deciduous', icon: '🌳', latin: 'Fraxinus excelsior' }
};

export const HABITAT_CODES = {
  BS: { namePl: 'Bór suchy', descPl: 'Ubogie, piaszczyste wydmy i piaski. Dominacja sosny i chrobotków.', moisture: 'dry' },
  'BŚW': { namePl: 'Bór świeży', descPl: 'Klasyczny las sosnowy z mchem, borówką i wrzosem. Najlepszy biotop na podgrzybki i borowiki.', moisture: 'optimal' },
  BW: { namePl: 'Bór wilgotny', descPl: 'Wilgotne piaski z poziomem wód gruntowych, mchy torfowce.', moisture: 'high' },
  BB: { namePl: 'Bór bagienny', descPl: 'Torfowiska wysokie z karłowatą sosną, bagno, żurawina.', moisture: 'bog' },
  'BMŚW': { namePl: 'Bór mieszany świeży', descPl: 'Sosna z domieszką dębu, brzozy i buka. Bardzo wysoka grzybodajność.', moisture: 'optimal' },
  BMW: { namePl: 'Bór mieszany wilgotny', descPl: 'Sosna, świerk, brzoza na wilgotnych glebach.', moisture: 'high' },
  BMB: { namePl: 'Bór mieszany bagienny', descPl: 'Sosna, świerk, brzoza na glebach torfowych.', moisture: 'bog' },
  'LMŚW': { namePl: 'Las mieszany świeży', descPl: 'Dąb, sosna, buk, grab. Bardzo bogate runo, świetne na borowiki i kurki.', moisture: 'optimal' },
  LMW: { namePl: 'Las mieszany wilgotny', descPl: 'Dąb, jesion, świerk na wilgotnych obniżeniach.', moisture: 'high' },
  'LŚW': { namePl: 'Las świeży', descPl: 'Dąbrowy, buczyny, grądy. Bogate gleby brunatne.', moisture: 'optimal' },
  LW: { namePl: 'Las wilgotny', descPl: 'Wilgotny las liściasty, dąb, jesion, wiąz.', moisture: 'high' },
  OL: { namePl: 'Ols', descPl: 'Czyste drzewostany olszowe na bagnach i torfach.', moisture: 'bog' },
  OLJ: { namePl: 'Ols jesionowy', descPl: 'Olsza z jesionem w dolinach rzek.', moisture: 'wet' },
  'LŁ': { namePl: 'Las łęgowy', descPl: 'Okresowo zalewane doliny rzeczne (topole, wierzby, jesiony).', moisture: 'wet' }
};

export const FUNCTION_CODES = {
  GOSP: { namePl: 'Las gospodarczy', status: 'allowed', labelPl: 'Zbiór dozwolony', color: '#10b981' },
  OCHR: { namePl: 'Las ochronny', status: 'allowed', labelPl: 'Las ochronny (Zbiór dozwolony)', color: '#3b82f6' },
  REZ: { namePl: 'Rezerwat przyrody', status: 'forbidden', labelPl: 'REZERWAT - ZAKAZ ZBIORU!', color: '#ef4444' },
  NP: { namePl: 'Park Narodowy', status: 'forbidden', labelPl: 'PARK NARODOWY - ZAKAZ ZBIORU!', color: '#ef4444' }
};

export function getSpeciesInfo(code) {
  if (!code) return { namePl: 'Nieokreślony', nameRu: 'Неопределено', icon: '🌱' };
  const clean = code.trim().toUpperCase();
  return SPECIES_CODES[clean] || { namePl: clean, nameRu: clean, icon: '🌲', type: 'unknown' };
}

export function getHabitatInfo(code) {
  if (!code) return { namePl: 'Nieokreślone', descPl: 'Brak danych siedliska', moisture: 'unknown' };
  const clean = code.trim().toUpperCase();
  return HABITAT_CODES[clean] || { namePl: clean, descPl: 'Siedlisko leśne', moisture: 'unknown' };
}

export function getFunctionInfo(code) {
  if (!code) return FUNCTION_CODES.GOSP;
  const clean = code.trim().toUpperCase();
  return FUNCTION_CODES[clean] || FUNCTION_CODES.GOSP;
}
