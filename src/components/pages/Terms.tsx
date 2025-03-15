import React from 'react';

const Terms = () => {
  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto bg-white rounded-lg shadow-lg p-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">Regulamin wypożyczalni SOLRENT</h1>
        
        <div className="space-y-6 text-gray-600">
          <section>
            <h2 className="text-xl font-semibold text-gray-800 mb-4">§1. Postanowienia ogólne</h2>
            <p>1. Niniejszy regulamin określa zasady wypożyczania sprzętu budowlanego i ogrodniczego przez SOLRENT Sp. z o.o.</p>
            <p>2. Wypożyczalnia prowadzi działalność w zakresie krótkoterminowego wynajmu sprzętu budowlanego i ogrodniczego.</p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-800 mb-4">§2. Zasady wypożyczania sprzętu</h2>
            <p>1. Wypożyczenie sprzętu następuje na podstawie złożonego zamówienia online lub bezpośrednio w siedzibie firmy.</p>
            <p>2. Warunkiem wypożyczenia sprzętu jest:</p>
            <ul className="list-disc pl-6 mt-2">
              <li>Ukończenie 18 roku życia</li>
              <li>Posiadanie ważnego dokumentu tożsamości</li>
              <li>Wpłacenie kaucji zwrotnej</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-800 mb-4">§3. Obowiązki Wypożyczającego</h2>
            <p>Wypożyczający zobowiązuje się do:</p>
            <ul className="list-disc pl-6 mt-2">
              <li>Użytkowania sprzętu zgodnie z jego przeznaczeniem i instrukcją obsługi</li>
              <li>Zwrotu sprzętu w stanie niepogorszonym</li>
              <li>Terminowego regulowania należności</li>
              <li>Pokrycia kosztów ewentualnych napraw lub odszkodowania</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-800 mb-4">§4. Rezerwacja sprzętu</h2>
            <p>1. Rezerwacji można dokonać online poprzez stronę internetową lub telefonicznie.</p>
            <p>2. Rezerwacja jest ważna po otrzymaniu potwierdzenia od wypożyczalni.</p>
            <p>3. Wypożyczalnia zastrzega sobie prawo do odmowy realizacji rezerwacji w przypadku:</p>
            <ul className="list-disc pl-6 mt-2">
              <li>Braku dostępności sprzętu</li>
              <li>Niespełnienia warunków wypożyczenia</li>
              <li>Wcześniejszych naruszeń regulaminu przez klienta</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-800 mb-4">§5. Płatności i kaucja</h2>
            <p>1. Opłata za wypożyczenie naliczana jest zgodnie z aktualnym cennikiem.</p>
            <p>2. Kaucja zwrotna jest zabezpieczeniem na wypadek uszkodzenia lub nieterminowego zwrotu sprzętu.</p>
            <p>3. Wysokość kaucji jest uzależniona od rodzaju wypożyczanego sprzętu.</p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-800 mb-4">§6. Odpowiedzialność</h2>
            <p>1. Wypożyczający ponosi pełną odpowiedzialność za wypożyczony sprzęt od momentu jego odbioru do zwrotu.</p>
            <p>2. W przypadku uszkodzenia, zniszczenia lub utraty sprzętu, Wypożyczający zobowiązany jest do pokrycia kosztów naprawy lub odkupienia sprzętu.</p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-800 mb-4">§7. Postanowienia końcowe</h2>
            <p>1. W sprawach nieuregulowanych niniejszym regulaminem zastosowanie mają przepisy Kodeksu Cywilnego.</p>
            <p>2. Wszelkie spory będą rozstrzygane przez sąd właściwy dla siedziby Wypożyczalni.</p>
          </section>
        </div>

        <div className="mt-8 pt-8 border-t border-gray-200">
          <p className="text-sm text-gray-500">
            Regulamin obowiązuje od dnia 01.03.2025 r.
            SOLRENT Sp. z o.o.
          </p>
        </div>
      </div>
    </div>
  );
};

export default Terms;