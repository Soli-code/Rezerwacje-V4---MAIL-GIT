import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../../lib/supabase';
import { 
  Package, Users, Calendar, FileText, PenTool as Tool, 
  AlertTriangle, DollarSign, ArrowUpRight, ArrowDownRight,
  BarChart2, TrendingUp, UserCheck
} from 'lucide-react';

interface StatCardProps {
  icon: React.ElementType;
  title: string;
  value: string | number;
  description: string;
  trend?: 'up' | 'down';
  percentage?: number;
}

const StatCard: React.FC<StatCardProps> = ({ icon: Icon, title, value, description, trend, percentage }) => {
  return (
    <div className="bg-white rounded-lg shadow p-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center">
          <Icon className="w-6 h-6 text-gray-500 mr-3" />
          <div>
            <h3 className="text-sm font-medium text-gray-500">{title}</h3>
            <div className="text-2xl font-semibold">{value}</div>
          </div>
        </div>
        {trend && (
          <div className={`flex items-center ${trend === 'up' ? 'text-green-500' : 'text-red-500'}`}>
            {trend === 'up' ? <ArrowUpRight className="w-4 h-4" /> : <ArrowDownRight className="w-4 h-4" />}
            <span className="text-sm ml-1">{percentage}%</span>
          </div>
        )}
      </div>
      <p className="mt-2 text-sm text-gray-500">{description}</p>
    </div>
  );
};

const BusinessDashboard = () => {
  const navigate = useNavigate();
  const [stats, setStats] = useState({
    totalEquipment: 0,
    activeReservations: 0,
    pendingReservations: 0,
    totalCustomers: 0,
    maintenanceNeeded: 0,
    totalRevenue: 0,
    returningCustomers: 0,
    averageRental: 0,
    popularEquipment: [],
    recentReservations: []
  });
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      // Pobierz zbliżające się zwroty
      const { data: upcomingReturns } = await supabase
        .from('reservations')
        .select(`
          id,
          end_date,
          customers (
            first_name,
            last_name
          ),
          reservation_items (
            equipment (
              name
            )
          )
        `)
        .in('status', ['confirmed', 'picked_up'])
        .gte('end_date', new Date().toISOString())
        .lte('end_date', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString())
        .order('end_date', { ascending: true });

      // Przetworz dane o zbliżających się zwrotach
      const processedReturns = upcomingReturns?.map(return_item => {
        const daysLeft = Math.ceil((new Date(return_item.end_date).getTime() - Date.now()) / (1000 * 60 * 60 * 24));
        return {
          id: return_item.id,
          reservation_id: return_item.id,
          customer_name: `${return_item.customers.first_name} ${return_item.customers.last_name}`,
          equipment_name: return_item.reservation_items[0]?.equipment.name,
          days_left: daysLeft
        };
      });

      // Pobierz statystyki sprzętu
      const { data: equipment } = await supabase
        .from('equipment')
        .select('id');
      
      // Pobierz aktywne rezerwacje
      const { data: activeReservations } = await supabase
        .from('reservations')
        .select('id')
        .in('status', ['confirmed']);

      // Pobierz oczekujące rezerwacje ze wszystkimi potrzebnymi danymi
      const { data: pendingReservations } = await supabase
        .from('reservations')
        .select(`
          id,
          created_at,
          start_date,
          end_date,
          total_price,
          status,
          customer:customers (
            first_name,
            last_name
          ),
          items:reservation_items (
            equipment:equipment (
              name
            ),
            quantity
          ),
          total_price
        `)
        .eq('status', 'pending')
        .is('is_reversed', false)
        .order('created_at', { ascending: false })
        .limit(10);

      // Pobierz klientów
      const { data: customers } = await supabase
        .from('customers')
        .select('id');

      // Pobierz sprzęt wymagający konserwacji
      const { data: maintenanceNeeded } = await supabase
        .from('maintenance_logs')
        .select('id')
        .eq('status', 'planned');

      // Pobierz sumę przychodów
      const { data: revenue } = await supabase
        .from('financial_transactions')
        .select('amount')
        .eq('status', 'completed')
        .eq('transaction_type', 'payment');

      setStats(prevStats => ({
        ...prevStats,
        totalEquipment: equipment?.length || 0,
        activeReservations: activeReservations?.length || 0,
        pendingReservations: pendingReservations?.length || 0,
        recentReservations: pendingReservations || [],
        totalCustomers: customers?.length || 0,
        maintenanceNeeded: maintenanceNeeded?.length || 0,
        totalRevenue: revenue?.reduce((sum, t) => sum + (t.amount || 0), 0) || 0,
        upcomingReturns: processedReturns || []
      }));
    } catch (error) {
      console.error('Error loading stats:', error);
      setError('Nie udało się załadować statystyk');
    }
  };

  return (
    <div className="space-y-6">
      {/* Główne statystyki */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        <StatCard
          icon={Package}
          title="Aktywne rezerwacje"
          value={stats.activeReservations}
          description="Obecnie wypożyczony sprzęt"
          trend="up"
          percentage={8}
        />
        <StatCard
          icon={DollarSign}
          title="Przychód miesięczny"
          value={`${stats.totalRevenue.toFixed(2)} zł`}
          description="Wzrost o 20% m/m"
          trend="up"
          percentage={20}
        />
        <StatCard
          icon={UserCheck}
          title="Stali klienci"
          value={`${stats.returningCustomers}`}
          description={`${stats.totalCustomers > 0 ? ((stats.returningCustomers / stats.totalCustomers) * 100).toFixed(1) : '0'}% wszystkich klientów`}
          trend="up"
          percentage={15}
        />
        <StatCard
          icon={Tool}
          title="Sprzęt do przeglądu"
          value={stats.maintenanceNeeded}
          description="Zaplanowane przeglądy"
          trend="down"
          percentage={5}
        />
      </div>

      {/* Wykres rezerwacji */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">
              Rezerwacje w czasie
            </h3>
            <select className="px-3 py-1 border rounded-lg text-sm">
              <option value="7days">Ostatnie 7 dni</option>
              <option value="30days">Ostatnie 30 dni</option>
              <option value="90days">Ostatnie 90 dni</option>
            </select>
          </div>
          <div className="h-64 flex items-center justify-center text-gray-500">
            Tutaj będzie wykres
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">
              Najpopularniejszy sprzęt
            </h3>
            <TrendingUp className="w-5 h-5 text-green-500" />
          </div>
          <div className="space-y-4">
            {stats.popularEquipment.map((item, index) => (
              <div key={item.id} className="flex items-center">
                <div className="w-8 text-sm text-gray-500">{index + 1}.</div>
                <div className="flex-1">
                  <div className="text-sm font-medium text-gray-900">
                    {item.equipment?.name || item.name}
                  </div>
                  <div className="text-sm text-gray-500">
                    {item.count} wypożyczeń
                  </div>
                </div>
                <div className="w-24 h-2 bg-gray-100 rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-green-500" 
                    style={{ 
                      width: `${stats.popularEquipment[0]?.count ? (item.count / stats.popularEquipment[0].count) * 100 : 0}%` 
                    }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Statystyki klientów */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            Statystyki klientów
          </h3>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-500">Nowi klienci (30 dni)</span>
              <span className="text-lg font-medium text-gray-900">24</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-500">Średni czas wynajmu</span>
              <span className="text-lg font-medium text-gray-900">
                {stats.averageRental.toFixed(1)} dni
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-500">Wskaźnik powrotów</span>
              <span className="text-lg font-medium text-gray-900">68%</span>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            Zbliżające się zwroty
          </h3>
          <div className="space-y-3">
            {stats.upcomingReturns?.map((return_item: any) => (
              <div 
                key={return_item.id} 
                className="flex items-center justify-between hover:bg-gray-50 p-2 rounded-lg cursor-pointer"
                onClick={() => navigate(`/admin/panel/reservations/${return_item.reservation_id}`)}
              >
                <div>
                  <div className="text-sm font-medium text-gray-900">
                    {return_item.customer_name}
                  </div>
                  <div className="text-sm text-gray-500">
                    {return_item.equipment_name}
                  </div>
                </div>
                <div className={`text-sm ${
                  return_item.days_left <= 1 ? 'text-red-600' : 
                  return_item.days_left <= 3 ? 'text-orange-600' : 
                  'text-green-600'
                }`}>
                  {return_item.days_left === 0 ? 'Dzisiaj' :
                   return_item.days_left === 1 ? 'Jutro' :
                   `Za ${return_item.days_left} dni`}
                </div>
              </div>
            ))}
            {(!stats.upcomingReturns || stats.upcomingReturns.length === 0) && (
              <p className="text-center text-gray-500">
                Brak zbliżających się zwrotów
              </p>
            )}
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            Ostatnie aktywności
            {stats.recentReservations.length > 0 && (
              <span className="ml-2 text-sm text-gray-500">
                ({stats.recentReservations.length})
              </span>
            )}
          </h3>
          <div className="space-y-4">
            {stats.recentReservations.map((reservation: any) => (
              <div 
                key={reservation.id} 
                className="p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors cursor-pointer"
                onClick={() => navigate(`/admin/panel/reservations/${reservation.id}`, {
                  state: { from: '/admin/panel/dashboard' }
                })}
              >
                <div className="flex justify-between items-start">
                  <div>
                    <div className="font-medium text-gray-900">
                      {reservation.customer.first_name} {reservation.customer.last_name}
                    </div>
                    <div className="text-sm text-gray-600">
                      {reservation.items.map((item: any) => 
                        `${item.equipment.name} (${item.quantity}x)`
                      ).join(', ')}
                    </div>
                    <div className="text-xs text-gray-500 mt-1">
                      {new Date(reservation.created_at).toLocaleString('pl-PL')}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-medium text-solrent-orange">
                      {reservation.total_price} zł
                    </div>
                  </div>
                </div>
              </div>
            ))}
            {stats.recentReservations.length === 0 && (
              <p className="text-center text-gray-500">
                Brak nowych rezerwacji
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default BusinessDashboard;