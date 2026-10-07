/**
 * Comprehensive Polish Mushrooms Knowledge Base & Biotope Correlation Rules
 */

export const MUSHROOMS = [
  {
    id: 'borowik_szlachetny',
    namePl: 'Borowik szlachetny (Prawdziwek)',
    nameRu: 'Белый гриб (Боровик)',
    nameLat: 'Boletus edulis',
    badge: 'Król Polskich Lasów',
    edibility: 'Jadalny (Wybitny)',
    edibilityColor: '#10b981',
    image: 'https://images.unsplash.com/photo-1543852786-1cf6624b9987?auto=format&fit=crop&w=400&q=80',
    preferredTrees: ['SO', 'ŚW', 'DB', 'BK'],
    treeWeight: 40,
    preferredAge: { min: 35, idealMin: 50, idealMax: 95, max: 150 },
    preferredHabitats: ['BŚW', 'BMŚW', 'LMŚW', 'LŚW'],
    seasonMonths: [6, 7, 8, 9, 10, 11], // Jun - Nov
    minRainfall14d: 15,
    descriptionPl: 'Najbardziej poszukiwany grzyb w Polsce. Żyje w mikoryzie ze starymi sosnami, świerkami i dębami.',
    tipsPl: 'Szukaj w ciepłych, dobrze naświetlonych borach na granicy mchów i borówczysk 2-4 dni po ulewnych deszczach.',
    lookalike: {
      namePl: 'Goryczak żółciowy (Szatan)',
      nameLat: 'Tylopilus felleus',
      isLethal: false,
      warningPl: 'Niejadalny z powodu piekielnie gorzkiego smaku. Rurki starszych okazów różowieją, a na trzonie ma ciemną wypukłą siateczkę.'
    }
  },
  {
    id: 'podgrzybek_brunatny',
    namePl: 'Podgrzybek brunatny',
    nameRu: 'Польский гриб (Коричневый)',
    nameLat: 'Imleria badia',
    badge: 'Najpospolitszy skarb',
    edibility: 'Jadalny (Bardzo smaczny)',
    edibilityColor: '#10b981',
    image: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=400&q=80',
    preferredTrees: ['SO', 'ŚW'],
    treeWeight: 45,
    preferredAge: { min: 30, idealMin: 40, idealMax: 80, max: 120 },
    preferredHabitats: ['BŚW', 'BMŚW', 'BS', 'BW'],
    seasonMonths: [7, 8, 9, 10, 11], // Jul - Nov
    minRainfall14d: 10,
    descriptionPl: 'Klasyk polskich borów sosnowych. Masowo występuje jesienią wśród zielonych mchów.',
    tipsPl: 'Uwielbia zwarte poduszki mchu w czystych sośninach. Po uciśnięciu rurki natychmiast sinieją.',
    lookalike: null
  },
  {
    id: 'pieprznik_jadalny',
    namePl: 'Pieprznik jadalny (Kurka)',
    nameRu: 'Лисичка обыкновенная',
    nameLat: 'Cantharellus cibarius',
    badge: 'Nigdy nie robaczywieje',
    edibility: 'Jadalny (Ceniony)',
    edibilityColor: '#10b981',
    image: 'https://images.unsplash.com/photo-1596704017254-9b121068fb31?auto=format&fit=crop&w=400&q=80',
    preferredTrees: ['SO', 'ŚW', 'DB', 'BK'],
    treeWeight: 35,
    preferredAge: { min: 20, idealMin: 35, idealMax: 70, max: 120 },
    preferredHabitats: ['BŚW', 'BMŚW', 'BS', 'LMŚW'],
    seasonMonths: [5, 6, 7, 8, 9, 10], // May - Oct
    minRainfall14d: 15,
    descriptionPl: 'Żółte złoto lasu. Rośnie w grupach na glebach piaszczystych i kwaśnych pośród mchu i igliwia.',
    tipsPl: 'Gdy znajdziesz jedną, rozejrzyj się w promieniu 10 metrów pod gałęziami i igliwiem.',
    lookalike: {
      namePl: 'Lisieczka pomarańczowa',
      nameLat: 'Hygrophoropsis aurantiaca',
      isLethal: false,
      warningPl: 'Słabo trująca / niestrawna. Ma cienki pomarańczowy kapelusz i gęste blaszki zamiast listewkowatych fałdów.'
    }
  },
  {
    id: 'maslak_zwyczajny',
    namePl: 'Maślak zwyczajny',
    nameRu: 'Маслёнок обыкновенный',
    nameLat: 'Suillus luteus',
    badge: 'Król młodników',
    edibility: 'Jadalny (Smaczny)',
    edibilityColor: '#10b981',
    image: 'https://images.unsplash.com/photo-1546842931-886c185b4c8c?auto=format&fit=crop&w=400&q=80',
    preferredTrees: ['SO'],
    treeWeight: 50,
    preferredAge: { min: 8, idealMin: 12, idealMax: 25, max: 40 }, // Młodniki!
    preferredHabitats: ['BŚW', 'BS', 'BMŚW'],
    seasonMonths: [5, 6, 7, 8, 9, 10],
    minRainfall14d: 10,
    descriptionPl: 'Ściśle związany z młodą sosną. Uwielbia nasłonecznione skraje lasu, pasy przeciwpożarowe i polany.',
    tipsPl: 'Szukaj w młodych uprawach sosnowych o wysokości 2-4m oraz w trawiastych młodnikach.',
    lookalike: null
  },
  {
    id: 'mleczaj_rydz',
    namePl: 'Mleczaj rydz (Rydz)',
    nameRu: 'Рыжик настоящий',
    nameLat: 'Lactarius deliciosus',
    badge: 'Arystokrata na maśle',
    edibility: 'Jadalny (Wyborny)',
    edibilityColor: '#10b981',
    image: 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=400&q=80',
    preferredTrees: ['SO'],
    treeWeight: 50,
    preferredAge: { min: 10, idealMin: 15, idealMax: 30, max: 45 },
    preferredHabitats: ['BŚW', 'BMŚW', 'BS'],
    seasonMonths: [8, 9, 10, 11], // Aug - Nov
    minRainfall14d: 12,
    descriptionPl: 'Wspaniały grzyb smażony na maśle. Wydziela pomarańczowe mleczko, które na powietrzu powoli zielenieje.',
    tipsPl: 'Szukaj w dobrze naświetlonych sośninach na glebach piaszczystych i wapiennych z trawiastym dnem.',
    lookalike: {
      namePl: 'Mleczaj wełnianka',
      nameLat: 'Lactarius torminosus',
      isLethal: false,
      warningPl: 'Trujący! Rośnie pod brzozami, ma wełnisty brzeg kapelusza i ostre, piekące BIAŁE mleczko (nie pomarańczowe).'
    }
  },
  {
    id: 'kozlarz_babka',
    namePl: 'Koźlarz babka',
    nameRu: 'Подберёзовик обыкновенный',
    nameLat: 'Leccinum scabrum',
    badge: 'Wierny towarzysz brzozy',
    edibility: 'Jadalny (Smaczny)',
    edibilityColor: '#10b981',
    image: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
    preferredTrees: ['BRZ'],
    treeWeight: 55,
    preferredAge: { min: 12, idealMin: 20, idealMax: 50, max: 80 },
    preferredHabitats: ['BMŚW', 'LMŚW', 'BW', 'BMW'],
    seasonMonths: [6, 7, 8, 9, 10],
    minRainfall14d: 10,
    descriptionPl: 'Obligatoryjny partner brzozy. Rośnie wszędzie tam, gdzie w lesie pojawia się choć kilka brzóz.',
    tipsPl: 'Wypatruj białych pni brzóz na krawędziach borów i w wilgotniejszych zagłębieniach terenu.',
    lookalike: null
  },
  {
    id: 'kozlarz_czerwony',
    namePl: 'Koźlarz czerwony (Krawiec)',
    nameRu: 'Подосиновик красный',
    nameLat: 'Leccinum aurantiacum',
    badge: 'Czerwony kapelusznik',
    edibility: 'Jadalny (Bardzo smaczny)',
    edibilityColor: '#10b981',
    image: 'https://images.unsplash.com/photo-1546842931-886c185b4c8c?auto=format&fit=crop&w=400&q=80',
    preferredTrees: ['OS', 'BRZ', 'DB'],
    treeWeight: 50,
    preferredAge: { min: 15, idealMin: 25, idealMax: 60, max: 90 },
    preferredHabitats: ['BMŚW', 'LMŚW', 'LŚW'],
    seasonMonths: [6, 7, 8, 9, 10],
    minRainfall14d: 12,
    descriptionPl: 'Jeden z najpiękniejszych grzybów o jaskrawo pomarańczowym kapeluszu i twardym, siniejącym miąższu.',
    tipsPl: 'Szukaj w pobliżu kęp osiki i młodych brzóz.',
    lookalike: null
  },
  {
    id: 'czubajka_kania',
    namePl: 'Czubajka kania (Sowa)',
    nameRu: 'Гриб-зонтик пёстрый',
    nameLat: 'Macrolepiota procera',
    badge: 'Leśny kotlet schabowy',
    edibility: 'Jadalny (Wyborny)',
    edibilityColor: '#10b981',
    image: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=400&q=80',
    preferredTrees: ['SO', 'DB', 'BK'],
    treeWeight: 25,
    preferredAge: { min: 25, idealMin: 40, idealMax: 90, max: 120 },
    preferredHabitats: ['BŚW', 'BMŚW', 'LMŚW', 'LŚW'],
    seasonMonths: [7, 8, 9, 10, 11],
    minRainfall14d: 15,
    descriptionPl: 'Ogromny grzyb o ruchomym pierścieniu na trzonie. Kapelusze panierowane jak schabowe to rarytas.',
    tipsPl: 'Lubi prześwietlone skraje lasów, polany, pobocza leśnych dróg i trawiastą ściółkę.',
    lookalike: {
      namePl: 'Muchomor sromotnikowy (Zielonawy)',
      nameLat: 'Amanita phalloides',
      isLethal: true,
      warningPl: 'ŚMIERTELNIE TRUJĄCY! Kania ma ZAWSZE ruchomy pierścień, pręgowany zygzakowaty trzon i suchy łuskowaty kapelusz. Muchomor ma pochwę u podstawy!'
    }
  }
];
