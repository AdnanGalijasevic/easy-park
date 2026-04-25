using System;
using System.Collections.Generic;

namespace EasyPark.Model.Models
{
    /// <summary>
    /// Describes the availability of a parking spot type over a day.
    /// BusySlots are time windows where ALL spots of this type are occupied.
    /// </summary>
    public class SpotTypeAvailability
    {
        public string SpotType { get; set; } = null!;
        public int TotalSpots { get; set; }
        public List<TimeSlot> BusySlots { get; set; } = new();
        public List<TimeSlot> FreeSlots { get; set; } = new();
    }

    public class TimeSlot
    {
        public DateTime Start { get; set; }
        public DateTime End { get; set; }
        /// <summary>How many spots are free in this slot (0 = fully occupied).</summary>
        public int AvailableSpots { get; set; }
    }
}
