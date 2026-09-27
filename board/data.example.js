// Example family board data (ships with raytube). Copy to data.js and edit; the board reloads it
// every minute. Times are 24-hour "HH:MM" and shown as the TV's local time.
window.BOARD_DATA = {
  // Month calendar. "day" = days from today (so the sample always looks current);
  // real events can use "date": "YYYY-MM-DD" instead. "who" is a person id or "family".
  calendar: {
    events: [
      { day: -6, time: "18:00", title: "Parent-teacher night", who: "sam" },
      { day: -3, time: "15:30", title: "Kai piano", who: "kai" },
      { day: -1, time: "17:00", title: "Mia's playdate", who: "mia" },
      { day: 0, time: "09:00", title: "Kai soccer", who: "kai" },
      { day: 0, time: "16:00", title: "Mia's swimming", who: "mia" },
      { day: 0, time: "18:30", title: "Pizza night", who: "family" },
      { day: 1, time: "12:00", title: "Lunch at Grandma's", who: "family" },
      { day: 2, time: "08:30", title: "School photos", who: "mia" },
      { day: 2, time: "15:30", title: "Kai piano", who: "kai" },
      { day: 3, time: "19:00", title: "Book club", who: "sam" },
      { day: 4, time: "11:30", title: "Dentist (Kai)", who: "kai" },
      { day: 5, time: "07:00", title: "Bins out", who: "alex" },
      { day: 7, time: "14:00", title: "Birthday party", who: "mia" },
      { day: 9, time: "09:00", title: "Car service", who: "alex" },
      { day: 11, time: "10:00", title: "School holidays start", who: "family" }
    ]
  },
  weather: { now: "19° partly cloudy", note: "showers after 3pm · take a jacket" },
  people: [
    {
      id: "alex", name: "Alex", role: "Parent", color: "#6fb3e8",
      events: [["09:00", "Kai to soccer"], ["11:30", "Car service"], ["14:00", "Project time"]],
      todoTitle: "To do",
      todos: [["Pay school excursion", false], ["Bins out", true]]
    },
    {
      id: "sam", name: "Sam", role: "Parent", color: "#ef93b8",
      events: [["08:00", "Yoga"], ["12:30", "Lunch with a friend"], ["16:00", "Mia's swimming"]],
      todoTitle: "Shopping",
      todos: [["Pasta, basil", false], ["Milk, eggs, bread", false], ["Limes", true]]
    },
    {
      id: "kai", name: "Kai", role: "10", color: "#7fd69a",
      events: [["09:00", "Soccer"]],
      streak: { label: "Reading streak", value: "6 days · 20 min today" },
      todoTitle: "Jobs",
      todos: [["Feed the fish", true], ["Tidy room", false]]
    },
    {
      id: "mia", name: "Mia", role: "5", color: "#ffcf5c",
      big: true,
      todoTitle: "My morning",
      todos: [["Teeth", true], ["Get dressed", true], ["Shoes on", false]],
      stars: 4
    }
  ]
};
