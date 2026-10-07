import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../domain/models.dart';

class BdlParser {
  /// Exhaustive Polish Forestry Tree Species Dictionary (BDL Lasów Państwowych)
  static const Map<String, Map<String, String>> speciesDict = {
    // === Iglaste (Conifers) ===
    'SO': {'pl': 'Sosna zwyczajna', 'ru': 'Сосна обыкновенная', 'latin': 'Pinus sylvestris', 'icon': '🌲'},
    'SO.C': {'pl': 'Sosna czarna', 'ru': 'Сосна чёрная', 'latin': 'Pinus nigra', 'icon': '🌲'},
    'SO.B': {'pl': 'Sosna Banksa', 'ru': 'Сосна Банкса', 'latin': 'Pinus banksiana', 'icon': '🌲'},
    'SO.L': {'pl': 'Sosna limba', 'ru': 'Сосна кедровая', 'latin': 'Pinus cembra', 'icon': '🌲'},
    'SO.W': {'pl': 'Sosna wejmutka', 'ru': 'Сосна Веймутова', 'latin': 'Pinus strobus', 'icon': '🌲'},
    'KOSZ': {'pl': 'Kosodrzewina', 'ru': 'Сосна горная', 'latin': 'Pinus mugo', 'icon': '🌲'},
    'ŚW': {'pl': 'Świerk pospolity', 'ru': 'Ель европейская', 'latin': 'Picea abies', 'icon': '🌲'},
    'ŚW.S': {'pl': 'Świerk srebrny (kłujący)', 'ru': 'Ель колючая', 'latin': 'Picea pungens', 'icon': '🌲'},
    'JD': {'pl': 'Jodła pospolita', 'ru': 'Пихта белая', 'latin': 'Abies alba', 'icon': '🌲'},
    'JD.K': {'pl': 'Jodła kaukaska', 'ru': 'Пихта Нордмана', 'latin': 'Abies nordmanniana', 'icon': '🌲'},
    'JD.O': {'pl': 'Jodła olbrzymia', 'ru': 'Пихта великая', 'latin': 'Abies grandis', 'icon': '🌲'},
    'MD': {'pl': 'Modrzew europejski', 'ru': 'Лиственница', 'latin': 'Larix decidua', 'icon': '🌲'},
    'MD.J': {'pl': 'Modrzew japoński', 'ru': 'Лиственница японская', 'latin': 'Larix kaempferi', 'icon': '🌲'},
    'DG': {'pl': 'Daglezja zielona', 'ru': 'Дугласия (Псевдотсуга)', 'latin': 'Pseudotsuga menziesii', 'icon': '🌲'},
    'CIS': {'pl': 'Cis pospolity', 'ru': 'Тис ягодный', 'latin': 'Taxus baccata', 'icon': '🌲'},
    'JAŁ': {'pl': 'Jałowiec pospolity', 'ru': 'Можжевельник обыкновенный', 'latin': 'Juniperus communis', 'icon': '🌲'},
    'JŁ': {'pl': 'Jałowiec pospolity', 'ru': 'Можжевельник обыкновенный', 'latin': 'Juniperus communis', 'icon': '🌲'},
    'ŻYW': {'pl': 'Żywotnik (Tuja)', 'ru': 'Туя', 'latin': 'Thuja', 'icon': '🌲'},
    'CYS': {'pl': 'Cyprysik', 'ru': 'Кипарисовик', 'latin': 'Chamaecyparis', 'icon': '🌲'},

    // === Liściaste (Deciduous) ===
    'DB': {'pl': 'Dąb szypułkowy', 'ru': 'Дуб черешчатый', 'latin': 'Quercus robur', 'icon': '🌳'},
    'DĄB': {'pl': 'Dąb szypułkowy', 'ru': 'Дуб черешчатый', 'latin': 'Quercus robur', 'icon': '🌳'},
    'DB.S': {'pl': 'Dąb szypułkowy', 'ru': 'Дуб черешчатый', 'latin': 'Quercus robur', 'icon': '🌳'},
    'DB.B': {'pl': 'Dąb bezszypułkowy', 'ru': 'Дуб скальный', 'latin': 'Quercus petraea', 'icon': '🌳'},
    'DB.C': {'pl': 'Dąb czerwony', 'ru': 'Дуб красный', 'latin': 'Quercus rubra', 'icon': '🌳'},
    'BK': {'pl': 'Buk zwyczajny', 'ru': 'Бук европейский', 'latin': 'Fagus sylvatica', 'icon': '🌳'},
    'GB': {'pl': 'Grab pospolity', 'ru': 'Граб обыкновенный', 'latin': 'Carpinus betulus', 'icon': '🌳'},
    'BRZ': {'pl': 'Brzoza brodawkowata', 'ru': 'Берёза повислая', 'latin': 'Betula pendula', 'icon': '🌳'},
    'BRZ.O': {'pl': 'Brzoza omszona', 'ru': 'Берёза пушистая', 'latin': 'Betula pubescens', 'icon': '🌳'},
    'OL': {'pl': 'Olsza czarna', 'ru': 'Ольха чёрная', 'latin': 'Alnus glutinosa', 'icon': '🌳'},
    'OLSZ': {'pl': 'Olsza czarna', 'ru': 'Ольха чёрная', 'latin': 'Alnus glutinosa', 'icon': '🌳'},
    'OL.S': {'pl': 'Olsza szara', 'ru': 'Ольха серая', 'latin': 'Alnus incana', 'icon': '🌳'},
    'OL.Z': {'pl': 'Olsza zielona', 'ru': 'Ольха зелёная', 'latin': 'Alnus alnobetula', 'icon': '🌳'},
    'OS': {'pl': 'Topola osika', 'ru': 'Осина', 'latin': 'Populus tremula', 'icon': '🌳'},
    'JS': {'pl': 'Jesion wyniosły', 'ru': 'Ясень обыкновенный', 'latin': 'Fraxinus excelsior', 'icon': '🌳'},
    'KL': {'pl': 'Klon zwyczajny', 'ru': 'Клён остролистный', 'latin': 'Acer platanoides', 'icon': '🌳'},
    'JW': {'pl': 'Jawor', 'ru': 'Клён белый (Явор)', 'latin': 'Acer pseudoplatanus', 'icon': '🌳'},
    'PKL': {'pl': 'Klon polny (Paklon)', 'ru': 'Клён полевой', 'latin': 'Acer campestre', 'icon': '🌳'},
    'KL.J': {'pl': 'Klon jesionolistny', 'ru': 'Клён ясенелистный', 'latin': 'Acer negundo', 'icon': '🌳'},
    'LP': {'pl': 'Lipa drobnolistna', 'ru': 'Липа мелколистная', 'latin': 'Tilia cordata', 'icon': '🌳'},
    'LIP': {'pl': 'Lipa drobnolistna', 'ru': 'Липа мелколистная', 'latin': 'Tilia cordata', 'icon': '🌳'},
    'LP.S': {'pl': 'Lipa szerokolistna', 'ru': 'Липа крупнолистная', 'latin': 'Tilia platyphyllos', 'icon': '🌳'},
    'WZ': {'pl': 'Wiąz górski', 'ru': 'Вяз шершавый', 'latin': 'Ulmus glabra', 'icon': '🌳'},
    'WIĄZ': {'pl': 'Wiąz górski', 'ru': 'Вяз шершавый', 'latin': 'Ulmus glabra', 'icon': '🌳'},
    'WZ.P': {'pl': 'Wiąz polny', 'ru': 'Вяз малый (Берест)', 'latin': 'Ulmus minor', 'icon': '🌳'},
    'WZ.S': {'pl': 'Wiąz szypułkowy', 'ru': 'Вяз гладкий', 'latin': 'Ulmus laevis', 'icon': '🌳'},
    'TP': {'pl': 'Topola biała', 'ru': 'Тополь белый', 'latin': 'Populus alba', 'icon': '🌳'},
    'TP.C': {'pl': 'Topola czarna', 'ru': 'Тополь чёрный', 'latin': 'Populus nigra', 'icon': '🌳'},
    'TP.B': {'pl': 'Topola balsamiczna', 'ru': 'Тополь бальзамический', 'latin': 'Populus balsamifera', 'icon': '🌳'},
    'WB': {'pl': 'Wierzba biała', 'ru': 'Ива белая', 'latin': 'Salix alba', 'icon': '🌳'},
    'WIERZ': {'pl': 'Wierzba biała', 'ru': 'Ива белая', 'latin': 'Salix alba', 'icon': '🌳'},
    'WB.K': {'pl': 'Wierzba krucha', 'ru': 'Ива ломкая', 'latin': 'Salix fragilis', 'icon': '🌳'},
    'WB.I': {'pl': 'Iwa (Wierzba iwa)', 'ru': 'Ива козья', 'latin': 'Salix caprea', 'icon': '🌳'},
    'AK': {'pl': 'Robinia akacjowa (Akacja)', 'ru': 'Робиния ложноакациевая', 'latin': 'Robinia pseudoacacia', 'icon': '🌳'},
    'CZRM': {'pl': 'Czeremcha pospolita', 'ru': 'Черёмуха обыкновенная', 'latin': 'Prunus padus', 'icon': '🌳'},
    'CZRM.A': {'pl': 'Czeremcha amerykańska', 'ru': 'Черёмуха поздняя', 'latin': 'Prunus serotina', 'icon': '🌳'},
    'JRZ': {'pl': 'Jarząb pospolity (Jarzębina)', 'ru': 'Рябина обыкновенная', 'latin': 'Sorbus aucuparia', 'icon': '🌳'},
    'JRZ.B': {'pl': 'Jarząb brekinia', 'ru': 'Рябина глоговина', 'latin': 'Sorbus torminalis', 'icon': '🌳'},
    'CZR': {'pl': 'Czereśnia ptasia', 'ru': 'Черешня', 'latin': 'Prunus avium', 'icon': '🌳'},
    'JAB': {'pl': 'Jabłoń dzika', 'ru': 'Яблоня лесная', 'latin': 'Malus sylvestris', 'icon': '🌳'},
    'GRUSZ': {'pl': 'Grusza polna', 'ru': 'Груша лесная', 'latin': 'Pyrus pyraster', 'icon': '🌳'},
    'ŚL': {'pl': 'Śliwa tarnina', 'ru': 'Тёрн', 'latin': 'Prunus spinosa', 'icon': '🌳'},
    'ORZ': {'pl': 'Orzech czarny / włoski', 'ru': 'Орех', 'latin': 'Juglans', 'icon': '🌳'},
    'KSZT': {'pl': 'Kasztanowiec biały', 'ru': 'Конский каштан', 'latin': 'Aesculus hippocastanum', 'icon': '🌳'},
    'PLT': {'pl': 'Platan klonolistny', 'ru': 'Платан', 'latin': 'Platanus acerifolia', 'icon': '🌳'},
  };

  /// Comprehensive Polish Forest Habitat Dictionary (Siedliskowe Typy Lasu - STL)
  static const Map<String, Map<String, String>> habitatDict = {
    // === Bory nizinne ===
    'BS': {'pl': 'Bór suchy', 'desc': 'Ubogie, piaszczyste wydmy i chrobotki. Głównie sucholubna sosna.', 'moisture': 'dry'},
    'BŚW': {'pl': 'Bór świeży', 'desc': 'Klasyczny bór sosnowy z mchem i borówką. Doskonały na borowiki i podgrzybki.', 'moisture': 'optimal'},
    'BW': {'pl': 'Bór wilgotny', 'desc': 'Wilgotne piaski z mchami torfowcami i borówką bagienną.', 'moisture': 'high'},
    'BB': {'pl': 'Bór bagienny', 'desc': 'Torfowiska wysokie z karłowatą sosną i żurawiną.', 'moisture': 'bog'},
    'BMŚW': {'pl': 'Bór mieszany świeży', 'desc': 'Sosna z dębem i brzozą. Bardzo wysoka grzybodajność.', 'moisture': 'optimal'},
    'BMW': {'pl': 'Bór mieszany wilgotny', 'desc': 'Sosna, świerk, brzoza na wilgotnych glebach.', 'moisture': 'high'},
    'BMB': {'pl': 'Bór mieszany bagienny', 'desc': 'Sosna, świerk i brzoza na glebach torfowych.', 'moisture': 'bog'},

    // === Lasy nizinne ===
    'LMŚW': {'pl': 'Las mieszany świeży', 'desc': 'Dąb, sosna, buk, grab. Świetne runo na borowiki, kurki i koźlarze.', 'moisture': 'optimal'},
    'LMW': {'pl': 'Las mieszany wilgotny', 'desc': 'Dąb, świerk, jesion w wilgotnych obniżeniach.', 'moisture': 'high'},
    'LMB': {'pl': 'Las mieszany bagienny', 'desc': 'Brzozowo-sosnowo-świerkowy las na glebach torfowych.', 'moisture': 'bog'},
    'LŚW': {'pl': 'Las świeży', 'desc': 'Bogate dąbrowy, buczyny i grądy na glebach brunatnych.', 'moisture': 'optimal'},
    'LW': {'pl': 'Las wilgotny', 'desc': 'Wilgotny las liściasty (dąb, jesion, grab, wiąz).', 'moisture': 'high'},
    'OL': {'pl': 'Ols (Oles)', 'desc': 'Drzewostany olszowe na bagnach i torfach z kępami i dolinkami.', 'moisture': 'bog'},
    'OLJ': {'pl': 'Ols jesionowy', 'desc': 'Olsza z jesionem w dolinach wolno płynących wód.', 'moisture': 'wet'},
    'LŁ': {'pl': 'Las łęgowy', 'desc': 'Okresowo zalewane doliny rzeczne (jesion, wiąz, topola, wierzba).', 'moisture': 'wet'},

    // === Siedliska wyżynne i górskie ===
    'BMWYŻŚW': {'pl': 'Bór mieszany wyżynny świeży', 'desc': 'Jodła, sosna, buk i dąb na wyżynach.', 'moisture': 'optimal'},
    'BMWYŻW': {'pl': 'Bór mieszany wyżynny wilgotny', 'desc': 'Jodła, świerk i buk na wilgotnych zboczach wyżyn.', 'moisture': 'high'},
    'LMWYŻŚW': {'pl': 'Las mieszany wyżynny świeży', 'desc': 'Buk, jodła, dąb, modrzew. Doskonałe na borowiki i rydze.', 'moisture': 'optimal'},
    'LMWYŻW': {'pl': 'Las mieszany wyżynny wilgotny', 'desc': 'Jodłowo-bukowy las na wilgotnych stokach.', 'moisture': 'high'},
    'LWYŻŚW': {'pl': 'Las wyżynny świeży', 'desc': 'Buczyny i grądy wyżynne.', 'moisture': 'optimal'},
    'LWYŻW': {'pl': 'Las wyżynny wilgotny', 'desc': 'Wilgotne lasy liściaste wyżyn.', 'moisture': 'high'},
    'BGŚW': {'pl': 'Bór górski świeży', 'desc': 'Świerczyny górskie z borówką czarną.', 'moisture': 'optimal'},
    'BGW': {'pl': 'Bór górski wilgotny', 'desc': 'Świerk na wilgotnych stokach górskich z torfowcami.', 'moisture': 'high'},
    'BGB': {'pl': 'Bór górski bagienny', 'desc': 'Karłowaty świerk na torfowiskach górskich.', 'moisture': 'bog'},
    'BMGŚW': {'pl': 'Bór mieszany górski świeży', 'desc': 'Świerk z jodłą i bukiem. Wybitny na borowiki szlachetne i ceglastopore.', 'moisture': 'optimal'},
    'BMGW': {'pl': 'Bór mieszany górski wilgotny', 'desc': 'Świerk, jodła i buk w wilgotnych partiach gór.', 'moisture': 'high'},
    'BMGB': {'pl': 'Bór mieszany górski bagienny', 'desc': 'Świerk i sosna na bagnach górskich.', 'moisture': 'bog'},
    'LMGŚW': {'pl': 'Las mieszany górski świeży', 'desc': 'Buk z jodłą i świerkiem (regiel dolny).', 'moisture': 'optimal'},
    'LMGW': {'pl': 'Las mieszany górski wilgotny', 'desc': 'Jodła i buk w dolinach potoków górskich.', 'moisture': 'high'},
    'LGŚW': {'pl': 'Las górski świeży', 'desc': 'Czysta buczyna karpacka i sudecka.', 'moisture': 'optimal'},
    'LGW': {'pl': 'Las górski wilgotny', 'desc': 'Buczyna i jaworzyna w wilgotnych żlebach.', 'moisture': 'high'},
    'OLG': {'pl': 'Ols górski', 'desc': 'Olsza szara wzdłuż potoków i rzek górskich.', 'moisture': 'wet'},
    'LŁG': {'pl': 'Las łęgowy górski', 'desc': 'Łęg nadrzeczny w górach z olszą i wierzbą.', 'moisture': 'wet'},
    'BWG': {'pl': 'Bór wysokogórski', 'desc': 'Górnoreglowe świerczyny i kosodrzewina.', 'moisture': 'high'},
  };

  /// Resolves human-readable species info, including base code prefix fallbacks
  static Map<String, String> getSpeciesInfo(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    if (speciesDict.containsKey(code)) {
      return speciesDict[code]!;
    }
    // Sub-code prefix check (e.g. "SO.C" -> if missing, try "SO")
    if (code.contains('.')) {
      final base = code.split('.').first;
      if (speciesDict.containsKey(base)) {
        final baseData = speciesDict[base]!;
        return {
          'pl': '${baseData['pl']} ($code)',
          'ru': baseData['ru']!,
          'latin': baseData['latin']!,
          'icon': baseData['icon']!,
        };
      }
    }
    return {
      'pl': code.isEmpty ? 'Gatunek nieokreślony' : 'Drzewostan ($code)',
      'ru': code,
      'latin': 'Gatunek drzewa',
      'icon': '🌳',
    };
  }

  /// Resolves human-readable habitat info, including code fallbacks
  static Map<String, String> getHabitatInfo(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    if (habitatDict.containsKey(code)) {
      return habitatDict[code]!;
    }
    return {
      'pl': code.isEmpty ? 'Siedlisko leśne' : 'Siedlisko ($code)',
      'desc': 'Siedlisko leśne Lasów Państwowych',
      'moisture': 'optimal',
    };
  }

  static ForestParcel? parseHtml({
    required String htmlString,
    required double lat,
    required double lng,
  }) {
    if (!htmlString.contains('<table') || !htmlString.contains('<tr>')) {
      return null;
    }

    final document = html_parser.parse(htmlString);
    final tables = document.querySelectorAll('table');
    final h5List = document.querySelectorAll('h5');

    final List<Map<String, String>> wydzielenieRows = [];
    Map<String, String>? lesnictwoMap;
    Map<String, String>? nadlesnictwoMap;

    for (var i = 0; i < tables.length; i++) {
      final title = i < h5List.length ? h5List[i].text : '';
      final table = tables[i];
      final trList = table.querySelectorAll('tr');
      if (trList.length < 2) continue;

      final thList = trList[0].querySelectorAll('th');
      final isWydzielenia = title.contains('Wydzielenia PGL LP');

      for (var r = 1; r < trList.length; r++) {
        final tdList = trList[r].querySelectorAll('td');
        final map = <String, String>{};
        for (var j = 0; j < thList.length && j < tdList.length; j++) {
          map[thList[j].text.trim().toLowerCase()] = tdList[j].text.trim();
        }

        if (isWydzielenia ||
            map.containsKey('subarea_id') ||
            map.containsKey('species_cd_d')) {
          wydzielenieRows.add(map);
        } else if (title.contains('Leśnictwa') ||
            map.containsKey('forest_range_name')) {
          lesnictwoMap ??= map;
        } else if (title.contains('Nadleśnictwa') ||
            map.containsKey('inspectorate_name')) {
          nadlesnictwoMap ??= map;
        }
      }
    }

    if (wydzielenieRows.isEmpty) {
      return null;
    }

    // Build all tree species in the stand (P3: Composite stands)
    final speciesList = <TreeSpecies>[];
    int maxAge = 0;

    for (final row in wydzielenieRows) {
      final rawSpecies = (row['species_cd_d'] ?? '').trim().toUpperCase();
      if (rawSpecies.isEmpty) continue;

      final rawAge = int.tryParse(row['species_age'] ?? '0') ?? 0;
      if (rawAge > maxAge) {
        maxAge = rawAge;
      }

      final rawShare = int.tryParse(row['part_cd'] ?? '10') ?? 10;
      // In BDL: part_cd is typically 1..10 where 10 = 100%, 7 = 70%
      final sharePercent = rawShare <= 10 ? rawShare * 10 : rawShare;

      final speciesData = getSpeciesInfo(rawSpecies);

      speciesList.add(
        TreeSpecies(
          code: rawSpecies,
          namePl: speciesData['pl']!,
          nameRu: speciesData['ru']!,
          latin: speciesData['latin']!,
          icon: speciesData['icon']!,
          sharePercent: sharePercent,
        ),
      );
    }

    if (speciesList.isEmpty) {
      return null;
    }

    // Sort descending by share percentage: highest share is primary
    speciesList.sort((a, b) => b.sharePercent.compareTo(a.sharePercent));
    final primarySpecies = speciesList.first;
    final secondarySpecies = speciesList.skip(1).toList();

    // Parcel attributes from primary row
    final primaryRow = wydzielenieRows.first;
    final rawHabitat = (primaryRow['site_type_cd'] ?? '').trim().toUpperCase();
    final rawFunc = (primaryRow['forest_func_cd'] ?? 'GOSP').trim().toUpperCase();
    final habitatData = getHabitatInfo(rawHabitat);

    final standAge = maxAge > 0
        ? maxAge
        : (int.tryParse(primaryRow['species_age'] ?? '0') ?? 0);

    String ageCategory = 'Średniowiek';
    if (standAge < 25) {
      ageCategory = 'Młodnik / Uprawa (10-25 lat)';
    } else if (standAge >= 25 && standAge < 50) {
      ageCategory = 'Drzewostan dojrzewający (25-50 lat)';
    } else if (standAge >= 50 && standAge < 90) {
      ageCategory = 'Dojrzały bór / las (50-90 lat)';
    } else if (standAge >= 90) {
      ageCategory = 'Starodrzew (>90 lat)';
    }

    final isForbidden = rawFunc == 'REZ' || rawFunc == 'NP';
    final status = ForestStatus(
      code: rawFunc,
      status: isForbidden ? ForestLegalStatus.forbidden : ForestLegalStatus.allowed,
      labelPl: isForbidden ? 'REZERWAT - ZAKAZ ZBIORU!' : 'Las gospodarczy (Zbiór dozwolony)',
      color: isForbidden ? const Color(0xFFEF4444) : const Color(0xFF10B981),
    );

    return ForestParcel(
      subareaId: primaryRow['subarea_id'] ?? '',
      address: primaryRow['adress_forest'] ?? 'Adres leśny',
      primarySpecies: primarySpecies,
      secondarySpecies: secondarySpecies,
      ageYears: standAge,
      ageCategory: ageCategory,
      habitat: ForestHabitat(
        code: rawHabitat,
        namePl: habitatData['pl']!,
        descPl: habitatData['desc']!,
        moisture: habitatData['moisture']!,
      ),
      status: status,
      areaHa: primaryRow['sub_area'],
      inspectorate: nadlesnictwoMap?['inspectorate_name'] ??
          lesnictwoMap?['forest_range_name'] ??
          'Nadleśnictwo LP',
      latitude: lat,
      longitude: lng,
    );
  }
}
