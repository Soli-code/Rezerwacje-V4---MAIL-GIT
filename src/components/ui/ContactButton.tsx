import React, { useState, useEffect, useRef } from 'react';
import { Phone, Mail, X } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { getContactInfo, ContactInfo } from '../../lib/contact';
import { useScrollPosition } from '../../lib/hooks.ts';

const ContactButton: React.FC = () => {
  const [isExpanded, setIsExpanded] = useState(false);
  const [contactInfo, setContactInfo] = useState<ContactInfo | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);
  const [isSticky, setIsSticky] = useState(false);
  const [showTooltip, setShowTooltip] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);
  const modalCheckRef = useRef<boolean>(false);
  const scrollY = useScrollPosition();

  useEffect(() => {
    if (isMobile) {
      setIsSticky(scrollY > 100);
    }
  }, [scrollY, isMobile]);

  useEffect(() => {
    const loadContactInfo = async () => {
      const info = await getContactInfo();
      setContactInfo(info);
    };

    loadContactInfo();

    const checkMobile = () => {
      setIsMobile(window.innerWidth <= 767);
    };

    const handleClickOutside = (event: MouseEvent) => {
      if (panelRef.current && !panelRef.current.contains(event.target as Node)) {
        setIsExpanded(false);
      }
    };

    checkMobile();
    window.addEventListener('resize', checkMobile);
    document.addEventListener('mousedown', handleClickOutside);

    return () => {
      window.removeEventListener('resize', checkMobile);
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const handleCall = () => {
    if (contactInfo) {
      window.location.href = `tel:${contactInfo.phone_number.replace(/\s/g, '')}`;
    }
  };

  const handleEmail = () => {
    if (contactInfo) {
      window.location.href = `mailto:${contactInfo.email}`;
    }
  };

  const isInModal = () => {
    const modalElement = document.querySelector('[role="dialog"]');
    return modalElement !== null;
  };

  useEffect(() => {
    const checkModal = () => {
      const isOpen = isInModal();
      if (modalCheckRef.current !== isOpen) {
        modalCheckRef.current = isOpen;
        setIsModalOpen(isOpen);
      }
    };

    checkModal();
    // Obserwuj zmiany w DOM
    const observer = new MutationObserver(checkModal);
    observer.observe(document.body, { 
      childList: true,
      subtree: true 
    });

    return () => observer.disconnect();
  }, []);

  return (
    <>
      {/* Mobile Version */}
      {isMobile && !isInModal() && !isModalOpen && (
        <div className={`fixed z-50 transition-all duration-300 ${
          isSticky 
            ? 'top-0 right-0 p-2 bg-white/70 backdrop-blur-md shadow-md w-full flex justify-end'
            : 'top-4 right-4'
        }`}>
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className="relative"
          >
            <motion.button
              whileHover={isSticky ? { scale: 1.05 } : { scale: 1.1 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => setIsExpanded(!isExpanded)}
              className={`flex items-center justify-center transition-all ${
                isSticky
                  ? 'bg-solrent-orange/90 hover:bg-solrent-orange px-4 py-2 rounded-lg text-white'
                  : 'w-[44px] h-[44px] bg-solrent-orange rounded-full shadow-lg'
              }`}
              aria-label={`Zadzwoń do nas: ${contactInfo?.phone_number}`}
              role="button"
              tabIndex={0}
              style={{
                WebkitTapHighlightColor: 'transparent',
                touchAction: 'manipulation'
              }}
            >
              <Phone className={`${isSticky ? 'w-4 h-4' : 'w-5 h-5'} text-white`} />
              {isSticky && (
                <span className="ml-2 text-sm font-medium">Kontakt</span>
              )}
            </motion.button>

            <AnimatePresence>
              {isExpanded && (
                <motion.div
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  className={`absolute right-0 mt-2 bg-white rounded-lg shadow-lg p-4 ${
                    isSticky ? 'top-full' : 'top-[120%]'
                  }`}
                >
                  <div className="space-y-3">
                    <button
                      onClick={handleCall}
                      className="flex items-center space-x-3 w-full px-4 py-2 hover:bg-gray-50 rounded-lg transition-colors"
                    >
                      <Phone className="w-5 h-5 text-solrent-orange" />
                      <span className="text-gray-700 font-medium whitespace-nowrap">
                        {contactInfo?.phone_number}
                      </span>
                    </button>
                    
                    <button
                      onClick={handleEmail}
                      className="flex items-center space-x-3 w-full px-4 py-2 hover:bg-gray-50 rounded-lg transition-colors"
                    >
                      <Mail className="w-5 h-5 text-solrent-orange" />
                      <span className="text-gray-700 font-medium">
                        {contactInfo?.email}
                      </span>
                    </button>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
          {isExpanded && <div className="fixed inset-0 -z-10" onClick={() => setIsExpanded(false)} />}
        </div>
      )}

      {/* Desktop Version */}
      {!isMobile && !isModalOpen && (
        <div className="fixed bottom-20 right-5 z-50">
          <AnimatePresence>
            {isExpanded ? (
              <motion.div
                ref={panelRef}
                initial={{ opacity: 0, y: 10, scale: 0.95 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: 10, scale: 0.95 }}
                transition={{ duration: 0.3, ease: 'easeInOut' }}
                className="bg-white rounded-lg shadow-lg p-4 pr-16"
              >
                <button
                  onClick={() => setIsExpanded(false)}
                  className="absolute top-2 right-2 p-1 hover:bg-gray-100 rounded-full transition-colors"
                  aria-label="Zamknij panel kontaktowy"
                >
                  <X className="w-4 h-4 text-gray-500" />
                </button>
                
                <div className="space-y-3">
                  <button
                    onClick={handleCall}
                    className="flex items-center space-x-3 w-full px-4 py-2 hover:bg-gray-50 rounded-lg transition-colors"
                    aria-label={`Zadzwoń do nas: ${contactInfo?.phone_number}`}
                  >
                    <Phone className="w-5 h-5 text-solrent-orange" />
                    <span className="text-gray-700 font-medium">
                      {contactInfo?.phone_number}
                    </span>
                  </button>
                  
                  <button
                    onClick={handleEmail}
                    className="flex items-center space-x-3 w-full px-4 py-2 hover:bg-gray-50 rounded-lg transition-colors"
                    aria-label={`Wyślij email: ${contactInfo?.email}`}
                  >
                    <Mail className="w-5 h-5 text-solrent-orange" />
                    <span className="text-gray-700 font-medium">
                      {contactInfo?.email}
                    </span>
                  </button>
                </div>
              </motion.div>
            ) : (
              <motion.button
                initial={{ scale: 0.8, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.95 }}
                onClick={() => setIsExpanded(true)}
                className="w-[60px] h-[60px] bg-solrent-orange rounded-full shadow-lg flex items-center justify-center"
                aria-label="Otwórz panel kontaktowy"
                role="button"
                tabIndex={0}
              >
                <Phone className="w-6 h-6 text-white" />
              </motion.button>
            )}
          </AnimatePresence>
        </div>
      )}
    </>
  );
};

export default ContactButton;