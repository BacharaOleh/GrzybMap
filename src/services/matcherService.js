/**
 * Mushroom Matching & Scoring Engine
 * Computes probability of occurrence based on forestry parameters, age, habitat, season, and rainfall.
 */

import { MUSHROOMS } from '../data/mushroomMatrix.js';

export function matchMushrooms(parcel, weather, selectedMonth = null) {
  if (!parcel || !parcel.found || parcel.isMacro) {
    return [];
  }

  // Use selected month or current month (1-12)
  const currentMonth = selectedMonth !== null ? selectedMonth : (new Date().getMonth() + 1);
  const speciesCode = parcel.species?.code?.trim()?.toUpperCase() || '';
  const speciesAge = parcel.age || 0;
  const habitatCode = parcel.habitat?.code?.trim()?.toUpperCase() || '';
  const share = (parcel.species?.sharePercent || 100) / 100;
  const rainBonus = weather?.rainBonusScore || 0;

  const results = MUSHROOMS.map(mush => {
    let treeScore = 0;
    let ageScore = 0;
    let habitatScore = 0;
    let seasonScore = 0;
    const matchReasons = [];
    const mismatchReasons = [];

    // 1. Tree Species Match (Max 40 points)
    if (mush.preferredTrees.includes(speciesCode)) {
      treeScore = mush.treeWeight * share;
      matchReasons.push(`Drzewostan: ${parcel.species.namePl} (${parcel.species.sharePercent}%)`);
    } else {
      treeScore = 5; // Low baseline
      mismatchReasons.push(`Rzadziej występuje pod: ${parcel.species.namePl}`);
    }

    // 2. Stand Age Match (Max 30 points)
    const { min, idealMin, idealMax, max } = mush.preferredAge;
    if (speciesAge >= idealMin && speciesAge <= idealMax) {
      ageScore = 30;
      matchReasons.push(`Optymalny wiek lasu: ${speciesAge} lat (idealny przedział: ${idealMin}-${idealMax})`);
    } else if (speciesAge >= min && speciesAge <= max) {
      ageScore = 18;
      matchReasons.push(`Wiek znośny: ${speciesAge} lat`);
    } else if (speciesAge < min) {
      ageScore = 3;
      mismatchReasons.push(`Za młody las (${speciesAge} lat, wymaga min. ${min} lat)`);
    } else {
      ageScore = 8;
      mismatchReasons.push(`Bardzo stary las (${speciesAge} lat)`);
    }

    // 3. Habitat Match (Max 15 points)
    if (mush.preferredHabitats.includes(habitatCode)) {
      habitatScore = 15;
      matchReasons.push(`Doskonałe siedlisko: ${parcel.habitat.namePl} (${habitatCode})`);
    } else {
      habitatScore = 4;
    }

    // 4. Seasonality Match (Max 15 points)
    if (mush.seasonMonths.includes(currentMonth)) {
      seasonScore = 15;
      matchReasons.push(`Aktywny sezon owocowania w wybranym miesiącu`);
    } else {
      seasonScore = 0;
      mismatchReasons.push(`Poza naturalnym okresem owocowania`);
    }

    // Total raw score (0-100) + rain modifier
    let rawScore = treeScore + ageScore + habitatScore + seasonScore + rainBonus;
    
    // Penalize heavily if completely off-season or wrong tree
    if (!mush.seasonMonths.includes(currentMonth)) {
      rawScore = Math.min(rawScore, 25);
    }
    if (!mush.preferredTrees.includes(speciesCode)) {
      rawScore = Math.min(rawScore, 40);
    }

    // Clamp between 5% and 96% (nature is never 100% guaranteed)
    const probability = Math.max(5, Math.min(96, Math.round(rawScore)));

    let chanceCategory = 'Niska';
    let chanceColor = '#ef4444'; // Red
    if (probability >= 70) {
      chanceCategory = 'Bardzo wysoka szansa!';
      chanceColor = '#10b981'; // Green
    } else if (probability >= 45) {
      chanceCategory = 'Umiarkowana szansa';
      chanceColor = '#f59e0b'; // Amber
    }

    return {
      mushroom: mush,
      probability,
      chanceCategory,
      chanceColor,
      treeScore: Math.round(treeScore),
      ageScore: Math.round(ageScore),
      habitatScore: Math.round(habitatScore),
      seasonScore: Math.round(seasonScore),
      matchReasons,
      mismatchReasons
    };
  });

  // Sort by probability descending
  results.sort((a, b) => b.probability - a.probability);

  return results;
}
