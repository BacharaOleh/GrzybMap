/**
 * Parking Radar & Compass Module
 * Calculates bearing and distance back to the parked vehicle without internet.
 */

export class ParkingRadar {
  constructor() {
    this.carLocation = null;
    this.currentLocation = null;
    this.watchId = null;
  }

  saveCarLocation(latlng) {
    this.carLocation = latlng;
    localStorage.setItem('grzybmap_car_spot', JSON.stringify(latlng));
    return this.carLocation;
  }

  loadSavedCar() {
    const saved = localStorage.getItem('grzybmap_car_spot');
    if (saved) {
      try {
        this.carLocation = JSON.parse(saved);
      } catch (e) {
        this.carLocation = null;
      }
    }
    return this.carLocation;
  }

  clearCar() {
    this.carLocation = null;
    localStorage.removeItem('grzybmap_car_spot');
  }

  calculateDistanceAndBearing(fromLatLng, toLatLng) {
    if (!fromLatLng || !toLatLng) return null;

    const lat1 = (fromLatLng.lat * Math.PI) / 180;
    const lat2 = (toLatLng.lat * Math.PI) / 180;
    const dLat = ((toLatLng.lat - fromLatLng.lat) * Math.PI) / 180;
    const dLng = ((toLatLng.lng - fromLatLng.lng) * Math.PI) / 180;

    // Haversine formula for distance in meters
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const R = 6371000; // Earth radius in meters
    const distanceMeters = Math.round(R * c);

    // Initial bearing formula
    const y = Math.sin(dLng) * Math.cos(lat2);
    const x =
      Math.cos(lat1) * Math.sin(lat2) -
      Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
    let bearing = (Math.atan2(y, x) * 180) / Math.PI;
    bearing = (bearing + 360) % 360;

    return {
      distanceMeters,
      bearingDegrees: Math.round(bearing),
      humanDistance: distanceMeters > 1000 ? `${(distanceMeters / 1000).toFixed(2)} km` : `${distanceMeters} m`,
      walkTimeMinutes: Math.round(distanceMeters / 75) // ~4.5 km/h forest walking speed
    };
  }
}
